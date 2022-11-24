.PHONY: clean data install create_report lint requirements sync_data_to_s3 sync_data_from_s3 build_container stop_container_all prune_container run_container run_container_gpu

#################################################################################
# GLOBALS                                                                       #
#################################################################################
PROJECT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
BUCKET = BucketName
MODELBUCKET = ModelBucketName
PROFILE = default
PROJECT_NAME := $(shell basename $(CURDIR))
PROJECT_NAME_LC := $(shell echo $(PROJECT_NAME) | tr A-Z a-z)
PYTHON_INTERPRETER = python3

ifeq (,$(shell which conda))
HAS_CONDA=False
else
HAS_CONDA=True
endif


## NOTE: Makefile will execute each line of the recipe in a separate sub-shell
## e.g. exporting PATH in one line will not affect what the command in the next Makefile
## line can see! If we want to allow conda activate to work, we need to run everything
## in a single shell, hence .ONESHELL
CONDA_ACTIVATE = source $$(conda info --base)/etc/profile.d/conda.sh ; conda activate ; conda activate
.ONESHELL:
SHELL := /bin/bash

#################################################################################
# COMMANDS                                                                      #
#################################################################################

## Install Python Dependencies
requirements: test_environment
	conda install --file conda-env.txt
	pip3 install -r pip3-requirements.txt

## Update pip and conda-env dependencies
update_dep:
	conda list --explicit > conda-env.txt
	conda env export > conda-env.yaml
	pip3 install --upgrade pip
	pip3 list --format=freeze --exclude src > pip3-requirements.txt

## create and install src package
install:
	pip3 install -e .

## Make Dataset
data: requirements
	$(PYTHON_INTERPRETER) src/data/make_dataset.py data/raw data/processed

## Convert Jupyter Notebook report to HTML and PDF
create_report:
	jupyter nbconvert --execute --to html --output-dir='./reports/html' notebooks/reports/*.ipynb 
	jupyter nbconvert --execute --to pdf --output-dir='./reports/pdf' notebooks/reports/*.ipynb 
	jupyter nbconvert --execute --to markdown --output-dir='./reports/md' notebooks/reports/*.ipynb 

## Delete all compiled Python files
clean:
	find . -type f -name "*.py[co]" -delete
	find . -type d -name "__pycache__" -delete

## Lint using flake8
lint:
	flake8 src

## Set up python interpreter environment
create_environment:
ifeq (True,$(HAS_CONDA))
		@echo ">>> Detected conda, creating conda environment."
ifeq (3,$(findstring 3,$(PYTHON_INTERPRETER)))
	conda create --name $(PROJECT_NAME) --file conda-env.txt python=3.8
else
	conda create --name $(PROJECT_NAME) --file conda-env.txt python=2.7
endif
		#@echo ">>> New conda env created. Activate with:\nsource activate $(PROJECT_NAME)"
		@echo ">>> New conda env ${PROJECT_NAME} created. Installing conda and pip dependencies."
		source ~/.bashrc
		$(CONDA_ACTIVATE) ${PROJECT_NAME}
		conda install --file conda-env.txt
		pip3 install -r pip3-requirements.txt
else
	$(PYTHON_INTERPRETER) -m pip install -q virtualenv virtualenvwrapper
	@echo ">>> Installing virtualenvwrapper if not already installed.\nMake sure the following lines are in shell startup file\n\
	export WORKON_HOME=$$HOME/.virtualenvs\nexport PROJECT_HOME=$$HOME/Devel\nsource /usr/local/bin/virtualenvwrapper.sh\n"
	@bash -c "source `which virtualenvwrapper.sh`;mkvirtualenv $(PROJECT_NAME) --python=$(PYTHON_INTERPRETER)"
	@echo ">>> New virtualenv created. Activate with:\nworkon $(PROJECT_NAME)"
endif

delete_environment:
		@echo ">>> Deleting environment."
	conda env remove -n ${PROJECT_NAME} 

## Test python environment is setup correctly
test_environment:
	$(PYTHON_INTERPRETER) test_environment.py


#################################################################################
# AWS Commands                                                                  #
#################################################################################
## Upload Data to S3
sync_data_to_s3:
ifeq (default,$(PROFILE))
	aws s3 sync data/raw s3://$(BUCKET)/data/raw
	aws s3 sync data/processed s3://$(BUCKET)/data/processed --delete
	aws s3 sync data/interim s3://$(BUCKET)/data/interim --delete
	aws s3 sync data/external s3://$(BUCKET)/data/external --delete
	
	aws s3 sync models/ s3://$(MODELBUCKET)/models
else
	aws s3 sync data/raw s3://$(BUCKET)/data/raw --profile $(PROFILE)
	aws s3 sync data/processed s3://$(BUCKET)/data/processed --profile $(PROFILE) --delete
	aws s3 sync data/interim s3://$(BUCKET)/data/interim --profile $(PROFILE) --delete
	aws s3 sync data/external s3://$(BUCKET)/data/external --profile $(PROFILE) --delete
	
	aws s3 sync models/ s3://$(MODELBUCKET)/models --profile $(PROFILE)
endif

## Download Data from S3
sync_data_from_s3:
ifeq (default,$(PROFILE))
	aws s3 sync s3://$(BUCKET)/data/raw data/raw
	aws s3 sync s3://$(BUCKET)/data/processed data/processed --delete
	aws s3 sync s3://$(BUCKET)/data/interim data/interim --delete
	aws s3 sync s3://$(BUCKET)/data/external data/external --delete

	aws s3 sync s3://$(MODELBUCKET)/models models/
else
	aws s3 sync s3://$(BUCKET)/data/raw data/raw --profile $(PROFILE)
	aws s3 sync s3://$(BUCKET)/data/processed data/processed --profile $(PROFILE) --delete
	aws s3 sync s3://$(BUCKET)/data/interim data/interim --profile $(PROFILE) --delete
	aws s3 sync s3://$(BUCKET)/data/external data/external --profile $(PROFILE) --delete
	
	aws s3 sync s3://$(MODELBUCKET)/models models/ --profile $(PROFILE)
endif


#################################################################################
# Docker Commands                                                               #
#################################################################################
build_container:
	docker build -t $(PROJECT_NAME_LC) .

stop_container_all:
	docker container stop $$(docker ps -a -q)

prune_container:
	docker container prune -f

run_container:
	docker run \
         --mount type=bind,source="/tmp",target="/tmp" \
         --mount type=bind,source="${PWD}",target="/home/${PROJECT_NAME_LC}" \
         --network="host" \
         -dit $(PROJECT_NAME_LC)
 
run_container_gpu:
	docker run \
         --mount type=bind,source="/tmp",target="/tmp" \
         --mount type=bind,source="${PWD}",target="/home/${PROJECT_NAME_LC}" \
         --network="host" \
         --gpus all \
         -dit $(PROJECT_NAME_LC)

# running jupyter inside container
run_container_jupyter:
	jupyter-notebook --ip 0.0.0.0 --no-browser --allow-root


#################################################################################
# PROJECT RULES                                                                 #
#################################################################################


#################################################################################
# Self Documenting Commands                                                     #
#################################################################################

.DEFAULT_GOAL := help

# Inspired by <http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html>
# sed script explained:
# /^##/:
# 	* save line in hold space
# 	* purge line
# 	* Loop:
# 		* append newline + line to hold space
# 		* go to next line
# 		* if line starts with doc comment, strip comment character off and loop
# 	* remove target prerequisites
# 	* append hold space (+ newline) to line
# 	* replace newline plus comments by `---`
# 	* print line
# Separate expressions are necessary because labels cannot be delimited by
# semicolon; see <http://stackoverflow.com/a/11799865/1968>
.PHONY: help
help:
	@echo "$$(tput bold)Available rules:$$(tput sgr0)"
	@echo
	@sed -n -e "/^## / { \
		h; \
		s/.*//; \
		:doc" \
		-e "H; \
		n; \
		s/^## //; \
		t doc" \
		-e "s/:.*//; \
		G; \
		s/\\n## /---/; \
		s/\\n/ /g; \
		p; \
	}" ${MAKEFILE_LIST} \
	| LC_ALL='C' sort --ignore-case \
	| awk -F '---' \
		-v ncol=$$(tput cols) \
		-v indent=19 \
		-v col_on="$$(tput setaf 6)" \
		-v col_off="$$(tput sgr0)" \
	'{ \
		printf "%s%*s%s ", col_on, -indent, $$1, col_off; \
		n = split($$2, words, " "); \
		line_length = ncol - indent; \
		for (i = 1; i <= n; i++) { \
			line_length -= length(words[i]) + 1; \
			if (line_length <= 0) { \
				line_length = ncol - indent - length(words[i]) - 1; \
				printf "\n%*s ", -indent, " "; \
			} \
			printf "%s ", words[i]; \
		} \
		printf "\n"; \
	}' \
	| more $(shell test $(shell uname) = Darwin && echo '--no-init --raw-control-chars')
