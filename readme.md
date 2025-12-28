# VPN Generator Distributor

> Более детальная инструкция будет доступна на русском языке [здесь](./readme.ru.md).

This is a Telegram bot to manage multiple VPN servers, which are provided by [the VPN Generator project](https://github.com/vpngen).

It **centralizes** the management of separate _VPNGen_ servers and its users automating most of the cumbersome manual labor.

The bot has a **public interface**:
it allows regular non tech-savvy users to request keys, delivers them automacially, and shares installation instructions.

In addition, the bot offers some **admin conveniences**:
- It cleans up the servers from inactive users on demand;
- The bot provides a simple support ticket system inside Telegram for users to contact maintainers;
- It allows maintainers to unilaterally reach VPN key holders.
- It lets maintainers to personalize some of the bot's public messages.
- Finally, the administrator can plainly issue a key without ever entering the server's admin panel. 

For managing **a single server** via Telegram privately, [VPN-Generator-Manager](https://github.com/4erdenko/VPN-Generator-Manager) can be of help.

The bot communicates in Russian only.

## Development

### Prerequistes

- Ruby 3.4.2
- SQLite3
```sh
  sudo apt update
  sudo apt install sqlite3 libsqlite3-dev
```

- `shadowsocks-libev`
```sh
  sudo apt update
  sudo apt install shadowsocks-libev
```

### Executables

- Populate your `.env` according to the [example file](./env.example)
- Install dependencies via `bundle i`

Then start the bot:
```sh
  bin/start
```

To start the bot in the IRB mode, run:
```sh
  bin/console
```

To run the tests:
```sh
  bin/test
```

## Deploy

Deploy using `docker-compose.yml`. Consult [the example file](./docker_compose.yml.example).
Double check whether the files in the mounted volumes - database, instructions, and slides - are persisted between deploys.
