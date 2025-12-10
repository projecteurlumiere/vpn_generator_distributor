FROM ruby:3.4

WORKDIR /app

RUN apt-get update && \
    apt-get install -y sqlite3 libsqlite3-dev shadowsocks-libev && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile* ./
RUN bundle install

COPY . .

CMD ["bin/start"]
