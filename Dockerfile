FROM ruby:4.0.1

WORKDIR /bot

RUN apt-get update && \
    apt-get install -y sqlite3 libsqlite3-dev shadowsocks-libev && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile* ./
RUN bundle install

COPY . .

CMD ["bin/start"]
