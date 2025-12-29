# VPN Generator Distributor

> Более детальная инструкция и скриншоты [доступны на русском языке](./readme.ru.md).

This is a Telegram bot to manage multiple VPN servers, which are provided by [the VPN Generator project](https://github.com/vpngen).

It **centralizes** management of separate _VPNGen_ servers automating most of the cumbersome manual labor.

The bot has a **public interface**:
it allows regular non tech-savvy users to request keys, delivers them automacially, and shares installation instructions with them.

In addition, the bot offers some **admin conveniences** via private interfaces:
- It cleans up the servers from inactive users on demand;
- The bot provides a simple support ticket system.
- When requesting support, user messages are redirected to the admin Telegram supergroup and back ensuring support agents don't have access to user's personal data
- It allows maintainers to unilaterally reach VPN key holders via mass message broadcasts;
- It lets maintainers to personalize some of the bot's public messages;
- Finally, the administrator can plainly issue keys without ever entering the server's admin panel.

For managing **a single server** via Telegram _privately_, [VPN-Generator-Manager](https://github.com/4erdenko/VPN-Generator-Manager) can be of help.

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

- Populate your `.env` according to the [example file](./env.example)
- Install dependencies via `bundle i`

### Executables


To start the bot:
```sh
bin/start
```

To start the bot in the IRB mode without Telegram listener:
```sh
bin/console
```

To run the tests:
```sh
bin/test
```

## Deploy

Deploy using `docker-compose.yml`. Consult [the example file](./docker_compose.yml.example).
Make sure the files in the mounted volumes - database, instructions, and slides - are persisted between deploys.
