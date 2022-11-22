FROM continuumio/anaconda3:latest

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y apt-transport-https ca-certificates gpg wget curl unzip tar g++ make git vim && \
    apt-get install -y doxygen && \
    apt-get install -y lcov gcovr && \
    apt-get install -y zstd && \
    apt-get install -y libasan6 && \
    apt-get install -y libcurl4-gnutls-dev && \
    apt-get install -y pandoc && \
    apt-get install -y texlive-xetex


# install tmux, vimrc
RUN apt install -y tmux htop
RUN cd \
    && git clone https://github.com/gpakosz/.tmux.git \
    && ln -s -f .tmux/.tmux.conf \
    && cp .tmux/.tmux.conf.local .
RUN git clone --depth=1 https://github.com/amix/vimrc.git ~/.vim_runtime \
    && sh ~/.vim_runtime/install_awesome_vimrc.sh

# install git prompt
RUN git clone https://github.com/magicmonty/bash-git-prompt.git ~/.bash-git-prompt --depth=1
RUN echo "if [ -f \"$HOME/.bash-git-prompt/gitprompt.sh\" ]; then\n"\
    "\tGIT_PROMPT_ONLY_IN_REPO=1\n"\
    "\tsource $HOME/.bash-git-prompt/gitprompt.sh\n"\
"fi" >> ~/.bashrc

# setup conda env
RUN echo "conda deactivate" >> ~/.bashrc

WORKDIR /home


CMD ["bash"]
