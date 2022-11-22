# Notebooks

## Naming Convention
Since notebooks are challenging objects for source control, we recommended not collaborating directly with others on Jupyter notebooks. There are two steps we recommend for using notebooks effectively:
1. Follow a naming convention that shows the owner and the order the analysis was done in. We use the format `<step>-<ghuser>-<description>.ipynb` (e.g. `0.3-bull-visualize-distributions.ipynb`).
2. Refactor the good parts. Don't write code to do the same task in multiple notebooks. If it's a data preprocessing task, put it in the pipeline at `src/data/maek_dataset.py` and load data from `data/interim`. If it's useful utility code, refactor it to `src`.
