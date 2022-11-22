PythonDataScience Starter Template
==============================

Project Organization
------------

    ├── LICENSE
    ├── Makefile           <- Makefile with commands like `make data` or `make train`
    ├── README.md          <- The top-level README for developers using this project.
    ├── data
    │   ├── external       <- Data from third party sources.
    │   ├── interim        <- Intermediate data that has been transformed.
    │   ├── processed      <- The final, canonical data sets for modeling.
    │   └── raw            <- The original, immutable data dump.
    │
    ├── docs               <- A default Sphinx project; see sphinx-doc.org for details
    │
    ├── models             <- Trained and serialized models, model predictions, or model summaries
    │
    ├── notebooks          <- Jupyter notebooks. Naming convention is a number (for ordering),
    │                         the creator's initials, and a short `-` delimited description, e.g.
    │                         `1.0-jqp-initial-data-exploration`.
    │
    ├── references         <- Data dictionaries, manuals, and all other explanatory materials.
    │
    ├── reports            <- Generated analysis as HTML, PDF, LaTeX, etc.
    │   └── figures        <- Generated graphics and figures to be used in reporting
    │
    ├── requirements.txt   <- The requirements file for reproducing the analysis environment, e.g.
    │                         generated with `pip freeze > requirements.txt`
    │
    ├── setup.py           <- makes project pip installable (pip install -e .) so src can be imported
    ├── src                <- Source code for use in this project.
    │   ├── __init__.py    <- Makes src a Python module
    │   │
    │   ├── data           <- Scripts to download or generate data
    │   │   └── make_dataset.py
    │   │
    │   ├── features       <- Scripts to turn raw data into features for modeling
    │   │   └── build_features.py
    │   │
    │   ├── models         <- Scripts to train models and then use trained models to make
    │   │   │                 predictions
    │   │   ├── predict_model.py
    │   │   └── train_model.py
    │   │
    │   └── visualization  <- Scripts to create exploratory and results oriented visualizations
    │       └── visualize.py
    │
    └── tox.ini            <- tox file with settings for running tox; see tox.readthedocs.io


--------

<p><small>Project based on the <a target="_blank" href="https://drivendata.github.io/cookiecutter-data-science/">cookiecutter data science project template</a>. #cookiecutterdatascience</small></p>

# How to use
## 1. Sync data from s3 by running
Before running this commnad, make sure to install awscli and configure your s3 bucket.
```
make sync_data_from_s3
```

## 2. build
### Local build
```
make create_environment
```
Then activate your environment:
```
conda activate <name of your env>
```
The default name is the name of your directory (all in lowercase).

### Using Docker (Recommended)
```
make build_container
make run_container
docker exec -it <container  name> bash
make create_environment
conda activate <name of your env>
```

## 3. Do Datasciency stuff!
### Data processing
When processing raw data or extracting features, run
```
make data
```

To run jupyter notebook inside your docker container, run:
```
make run_container_jupyter
```
inside the container.


## 4. Finishing up
Before finishing up your work, you need to 
1. sync processed data to s3
```
make sync_data_to_s3
```
Note that raw data do not get synced to s3 (but you can change your Makefile if you wish to sync raw data)

2. Tidy up your code by running:
```
make lint
```

3. update the dependencies that you've installed while working:
```
make update_dep
```

4. Delete all compiled python files by running
```
make clean
```
