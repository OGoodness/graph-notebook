FROM amazonlinux:latest as base
FROM base as builder

# Notebook Port
EXPOSE 8888
# Lab Port
EXPOSE 8889
USER root

# May need to be set to `pipargs=' -i https://pypi.tuna.tsinghua.edu.cn/simple '` for china regions
ENV pipargs=""
ENV WORKING_DIR="/root"
ENV NOTEBOOK_DIR="${WORKING_DIR}/notebooks"
ENV EXAMPLE_NOTEBOOK_DIR="${NOTEBOOK_DIR}/Example Notebooks"
ENV NODE_VERSION=12.x
ENV GRAPH_NOTEBOOK_AUTH_MODE="DEFAULT"
ENV GRAPH_NOTEBOOK_HOST="neptune.cluster-XXXXXXXXXXXX.us-east-1.neptune.amazonaws.com"
ENV GRAPH_NOTEBOOK_PROXY_PORT="8192"
ENV GRAPH_NOTEBOOK_PROXY_HOST=""
ENV GRAPH_NOTEBOOK_PORT="8182"
ENV NEPTUNE_LOAD_FROM_S3_ROLE_ARN=""
ENV AWS_REGION="us-east-1"
ENV NOTEBOOK_PORT="8888"
ENV LAB_PORT="8889"
ENV GRAPH_NOTEBOOK_SSL="True"
ENV NOTEBOOK_PASSWORD="admin"
ENV PROVIDE_EXAMPLES=1


# "when the SIGTERM signal is sent to the docker process, it immediately quits and all established connections are closed"
# "graceful stop is triggered when the SIGUSR1 signal is sent to the docker process"
STOPSIGNAL SIGUSR1
RUN mkdir -p "${WORKING_DIR}" && \
    mkdir -p "${NOTEBOOK_DIR}" && \
    mkdir -p "${EXAMPLE_NOTEBOOK_DIR}" && \
    # Yum Update and install dependencies
    yum update -y && \
    yum install tar gzip git -y && \
    # Install NPM/Node
    curl --silent --location https://rpm.nodesource.com/setup_${NODE_VERSION} | bash - && \
    yum install nodejs -y && \
    npm install -g opencollective && \
    yum install python3 -y && \
    python3 -m ensurepip --upgrade  && \
    python3 -m venv /tmp/venv && \
    source /tmp/venv/bin/activate && \
    cd "${WORKING_DIR}" && \
    # Clone the repo and install python dependencies
    git clone https://github.com/aws/graph-notebook && \
    cd "${WORKING_DIR}/graph-notebook" && \
    pip3 install --upgrade pip setuptools wheel twine && \
    pip3 install -r requirements.txt && \
    pip3 install "jupyterlab>=3" && \
    # Build the package
    python3 setup.py sdist bdist_wheel && \
    # install the copied repo
    pip3 install . && \
    # copy premade starter notebooks
    cd "${WORKING_DIR}/graph-notebook" && \
    python3 -m graph_notebook.notebooks.install --destination "${EXAMPLE_NOTEBOOK_DIR}" && \
    jupyter nbextension enable  --py --sys-prefix graph_notebook.widgets && \
    # This allows for the `.ipython` to be set
    python -m graph_notebook.start_jupyterlab --jupyter-dir "${NOTEBOOK_DIR}"
    # # Cleanup
    # yum clean all && \
    # yum remove wget tar git  -y && \
    # rm -rf /var/cache/yum && \
    # rm -rf "${WORKING_DIR}/graph-notebook"


FROM base as runner

COPY --from=builder "${WORKING_DIR}" "${WORKING_DIR}"
COPY --from=builder /tmp/venv /tmp/venv

ADD ./docker/service.sh /usr/bin/service.sh


# RUN mkdir -p "${WORKING_DIR}" && \
#     mkdir -p "${NOTEBOOK_DIR}" && \
#     mkdir -p "${EXAMPLE_NOTEBOOK_DIR}" && \
#     # Yum Update and install dependencies
#     yum update -y && \
#     yum install tar gzip git -y && \
#     # Install NPM/Node
#     curl --silent --location https://rpm.nodesource.com/setup_${NODE_VERSION} | bash - && \
#     yum install nodejs -y && \
#     npm install -g opencollective && \
#     yum install python3 -y && \
#     python3 -m ensurepip --upgrade  && \
#     python3 -m venv /tmp/venv && \
#     source /tmp/venv/bin/activate && \
#     cd "${WORKING_DIR}" && \
#     # Clone the repo and install python dependencies
#     git clone https://github.com/aws/graph-notebook && \
#     cd "${WORKING_DIR}/graph-notebook" && \
#     pip3 install --upgrade pip setuptools wheel twine && \
#     pip3 install -r requirements.txt && \
#     pip3 install "jupyterlab>=3" && \
#     # Build the package
#     python3 setup.py sdist bdist_wheel && \
#     # install the copied repo
#     pip3 install . && \
#     # copy premade starter notebooks
#     cd "${WORKING_DIR}/graph-notebook" && \
#     python3 -m graph_notebook.notebooks.install --destination "${EXAMPLE_NOTEBOOK_DIR}" && \
#     jupyter nbextension enable  --py --sys-prefix graph_notebook.widgets && \
#     # This allows for the `.ipython` to be set
#     python -m graph_notebook.start_jupyterlab --jupyter-dir "${NOTEBOOK_DIR}" && \
#     # Cleanup
#     yum clean all && \
#     yum remove wget tar git  -y && \
#     rm -rf /var/cache/yum && \
#     rm -rf "${WORKING_DIR}/graph-notebook"

ADD "docker/Example-Remote-Server-Setup.ipynb" "${NOTEBOOK_DIR}/Example-Remote-Server-Setup.ipynb"
ADD ./docker/service.sh /usr/bin/service.sh

ENTRYPOINT [ "bash","-c","service.sh" ]
