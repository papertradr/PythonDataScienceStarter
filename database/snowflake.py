from __future__ import annotations

import os
from collections import defaultdict
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional
from dotenv import load_dotenv, find_dotenv

import pandas as pd
import sqlalchemy
from sqlalchemy import create_engine, text
from sqlalchemy.sql.schema import Column, Table

# find .env automatically by walking up directories until it's found
dotenv_path = find_dotenv()

# load up the entries as environment variables
load_dotenv(dotenv_path)

def fmt_exist_ok(exist_ok: bool):
    return "IF NOT EXISTS" if exist_ok else ""


class Snowflake:
    account = os.environ.get("SF_ACCOUNT")

    def __init__(
        self,
        role: Optional[str] = None,
        warehouse: Optional[str] = None,
        database: Optional[str] = None,
        user: Optional[str] = None,
        password: Optional[str] = None,
    ):
        if role is None:
            role = "public"
        if warehouse is None:
            warehouse = "COMPUTE_WH"
        if user is None:
            user = os.environ["QRAFT_ACCOUNT"]
        if password is None:
            password = os.environ["QRAFT_PASSWORD"]
        if database is None:
            database = ""

        self._engine = create_engine(
            f"snowflake://{user}:{password}@{self.account}/{database}?role={role}&warehouse={warehouse}"
        )
        self._meta_data = sqlalchemy.MetaData(bind=self._engine)

    def connect(self):
        return self._engine.connect()

    def create_database(
        self,
        db_name: str,
        exist_ok: bool = True,
        use: bool = True,
        allow_public_usage: bool = False,
    ):
        with self.connect() as con:
            res = con.execute(f"CREATE DATABASE {fmt_exist_ok(exist_ok)} {db_name}")
            if use:
                con.execute(f"USE DATABASE {db_name}")
            if allow_public_usage:
                con.execute(f"GRANT USAGE ON DATABASE {db_name} TO PUBLIC")
        return res.fetchall()

    def create_schema(
        self,
        schema_name: str,
        exist_ok: bool = True,
        use: bool = True,
        allow_public_usage: bool = False,
    ):
        with self.connect() as con:
            res = con.execute(f"CREATE SCHEMA {fmt_exist_ok(exist_ok)} {schema_name}")
            if use:
                con.execute(f"USE SCHEMA {schema_name}")
            if allow_public_usage:
                con.execute(f"GRANT USAGE ON SCHEMA {schema_name} TO PUBLIC")
            return res.fetchall()

    def create_table(
        self,
        table_name: str,
        columns: List[Column],
        temporary=False,
        allow_public_access: bool = False,
    ):
        prefixes = []
        if temporary:
            prefixes.append("TEMPORARY")
        table = sqlalchemy.Table(table_name, self._meta_data, *columns, prefixes=prefixes)
        self._meta_data.create_all()
        if allow_public_access:
            with self.connect() as con:
                con.execute(f"GRANT SELECT,REFERENCES ON TABLE {table_name} TO ROLE public")
        return table

    def create_stage(
        self,
        stage_name: str,
        sep: str = ",",
        compression: str = "gzip",
        skip_header: int = 0,
        exist_ok: bool = True,
    ):
        with self.connect() as con:
            return con.execute(
                f"""
                CREATE stage {fmt_exist_ok(exist_ok)} {stage_name}
                file_format = (type ='CSV' field_delimiter = '{sep}' field_optionally_enclosed_by='"' skip_header={skip_header} compression={compression});
                """
            ).fetchall()

    def put_to_stage(
        self,
        stage_name: str,
        path: Path,
        overwrite: bool = True,
    ):
        with self.connect() as con:
            return con.execute(
                f"PUT 'file://{path.absolute().as_posix()}' '{stage_name}' overwrite={overwrite};"
            ).fetchall()

    def drop_table(
        self,
        table_name: str,
    ):
        with self.connect() as con:
            con.execute(f"DROP TABLE IF EXISTS {table_name}")

    def merge_into_table(
        self,
        source_name: str,
        table: Table,
        comp_cols: List[str],
        column_mapping_fn: Optional[Dict[str, Callable[[str], str]]] = None,
    ):
        if column_mapping_fn is None:
            column_mapping_fn = {}
        column_mapping_fn = defaultdict(lambda: lambda x: x, column_mapping_fn)
        columns = [col.name for col in table.columns]
        cols = ",".join(columns)
        src_cols = ",".join(f"source.{col}" for col in columns)

        alias_cols = []
        for i, col in enumerate(columns):
            mapped = column_mapping_fn[col](f"${i + 1} {col}")
            alias_cols.append(mapped)
        alias_cols = ", ".join(alias_cols)

        match_cond = " AND ".join(f"target.{col} = source.{col}" for col in comp_cols)

        query = f"""
        MERGE INTO {table.name} target
        using (SELECT {alias_cols} FROM {source_name}) source
        on {match_cond}
        WHEN NOT matched THEN
            INSERT ({cols}) VALUES({src_cols})
        """
        with self.connect() as con:
            return con.execute(query).fetchall()

    def merge_dataframe_into_table(
        self,
        df: pd.DataFrame,
        table: Table,
        comp_cols: List[str],
        stage_prefix: str = "STAGE",
    ):
        df = df[[col.name for col in table.columns]]
        stage_table = f"{stage_prefix}_{table.name}"

        with self.connect() as con:
            df.to_sql(stage_table, if_exists="fail", con=con, index=False)
        self.merge_into_table(stage_table, table, comp_cols=comp_cols)
        with self.connect() as con:
            con.execute(f"DROP TABLE {stage_table}")

    def read_sql(
        self,
        sql: str,
        params: Optional[Dict[str, Any]] = None,
        index_col: str | List[str] | None = None,
    ):
        with self.connect() as con:
            df = pd.read_sql(
                text(sql),
                params=params,
                con=con,
                index_col=index_col,
            )
        df.columns = [col.lower() for col in df.columns]
        return df

    def execute(self, sql: str):
        with self.connect() as con:
            return con.execute(sql)

