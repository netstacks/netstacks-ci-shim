FROM ubuntu:22.04

ARG RUNNER_VERSION=2.323.0

RUN apt-get update && apt-get install -y \
    curl jq git python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install jinja2 pyyaml ncclient pygnmi deepdiff

RUN useradd -m runner
WORKDIR /home/runner

RUN curl -o actions-runner.tar.gz -L \
    https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && tar xzf actions-runner.tar.gz \
    && rm actions-runner.tar.gz \
    && ./bin/installdependencies.sh

RUN chown -R runner:runner /home/runner

COPY entrypoint.sh /home/runner/entrypoint.sh
RUN chmod +x /home/runner/entrypoint.sh

USER runner

ENTRYPOINT ["/home/runner/entrypoint.sh"]
