FROM ubuntu

# パッケージのインストール
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NOWARNINGS=yes
RUN apt-get update \
    && apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y \
        # ほぼ必須
        curl \
        less \
        sudo \
        unzip \
        vim \
        wget \
        # エディタ
        emacs \
        hexedit \
        # システム・ネットワーク診断系
        dstat \
        htop \
        iproute2 \
        lsof \
        mtr \
        net-tools \
        traceroute \
        # pyenv要件
        build-essential \
        git \
        libbz2-dev \
        libffi-dev \
        liblzma-dev \
        libncurses5-dev \
        libreadline-dev \
        libsqlite3-dev \
        libssl-dev \
        libxml2-dev \
        libxmlsec1-dev \
        llvm \
        make \
        tk-dev \
        xz-utils \
        zlib1g-dev \
        # その他
        apt-utils \
        language-pack-ja \
        language-pack-ja-base \
        locales \
        man-db \
        manpages-ja \
        manpages-ja-dev \
        openssh-server \
        sox \
        tree \
        tzdata \
        xdg-utils \
    && apt-get clean -y \
    && rm -rf \
        /var/lib/apt/lists/* \
        /var/cache/apt/* \
        /usr/local/src/* \
        /tmp/*

# rootにパスワードを設定
RUN echo "root:root000" | chpasswd

# ユーザ作成
RUN adduser -q --gecos "" --disabled-login admin \
    && usermod -aG sudo admin \
    && echo "admin:admin000" | chpasswd

# 日本語環境の設定
RUN locale-gen ja_JP.UTF-8 \
    && echo "export TZ=Asia/Tokyo" > /etc/profile.d/ja_tokyo.sh \
    && echo "export LANG=ja_JP.UTF-8" >> /etc/profile.d/ja_tokyo.sh \
    && echo "export LANGUAGE=ja_JP:ja" >> /etc/profile.d/ja_tokyo.sh

# SSHサーバの設定
RUN mkdir /var/run/sshd \
    && sed -i -e "s/^#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config \
    && sed -i -e "s/^#PasswordAuthentication/PasswordAuthentication/" /etc/ssh/sshd_config \
    && sed -i -e "s/^#UseDNS yes/UseDNS no/" /etc/ssh/sshd_config

# pyenvのインストール
RUN git clone https://github.com/pyenv/pyenv.git /usr/local/pyenv \
    && git clone https://github.com/pyenv/pyenv-update.git /usr/local/pyenv/plugins/pyenv-update \
    && echo 'export PYENV_ROOT="/usr/local/pyenv"' >> /etc/profile.d/pyenv.sh \
    && echo 'export PATH="${PYENV_ROOT}/bin:${PATH}"' >> /etc/profile.d/pyenv.sh \
    && echo 'eval "$(pyenv init - --no-rehash)"' >> /etc/profile.d/pyenv.sh

# Python仮想環境のインストール
RUN . /etc/profile.d/pyenv.sh \
    && pyenv install miniconda3-latest

# Pythonパッケージをcondaでインストール
RUN . /etc/profile.d/pyenv.sh \
    && pyenv global miniconda3-latest \
    && conda config --add channels conda-forge \
    && conda update -y conda \
    && conda update -y --all \
    && conda install -y \
        ipywidgets \
        joblib \
        jupyterlab \
        matplotlib \
        nodejs=12 \
        numpy \
        openpyxl \
        pandas \
        scipy \
        seaborn \
        xeus-python \
        xlrd=1.2.0 \
    && conda clean -y --all

# condaにないパッケージをpipでインストール
RUN . /etc/profile.d/pyenv.sh \
    && pyenv global miniconda3-latest \
    && python -m pip install \
        japanize-matplotlib \
        # jupyterlab-kite \
    && rm -rf /root/.cache/pip

# JupyterLabの設定
RUN echo "c = get_config()" >> /usr/local/pyenv/versions/miniconda3-latest/etc/jupyter/jupyter_config.py \
    && echo "c.NotebookApp.allow_remote_access = True" >> /usr/local/pyenv/versions/miniconda3-latest/etc/jupyter/jupyter_config.py \
    && echo "c.NotebookApp.allow_root = True" >> /usr/local/pyenv/versions/miniconda3-latest/etc/jupyter/jupyter_config.py \
    && echo "c.NotebookApp.ip = '0.0.0.0'" >> /usr/local/pyenv/versions/miniconda3-latest/etc/jupyter/jupyter_config.py \
    && echo "c.NotebookApp.open_browser = False" >> /usr/local/pyenv/versions/miniconda3-latest/etc/jupyter/jupyter_config.py \
    && echo "c.NotebookApp.port = 8888" >> /usr/local/pyenv/versions/miniconda3-latest/etc/jupyter/jupyter_config.py \
    && echo "c.NotebookApp.token = ''" >> /usr/local/pyenv/versions/miniconda3-latest/etc/jupyter/jupyter_config.py

# kite (Pythonコード補完ツール) のインストール
WORKDIR /root
RUN wget https://linux.kite.com/dls/linux/current \
    && chmod +x current \
    && sed -i 's/"--no-launch"//g' current > /dev/null \
    && ./current --install ./kite-installer \
    && rm -f current

# JupyterLabの拡張機能のインストール
RUN . /etc/profile.d/pyenv.sh \
    && jupyter labextension install \
        @jupyterlab/debugger \
        @jupyterlab/toc \
        # @lckr/jupyterlab_variableinspector \
    && jupyter labextension update --all --minimize=False \
    && jupyter lab build --minimize=False

# 使用ポート
EXPOSE 22 8888

# SSHサーバを起動する
CMD ["/usr/sbin/sshd", "-D"]
