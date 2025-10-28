# Claude Agent Rails Spike

This is an exploration into 3 different approaches to integrating Claude Code /
Claude Agent with a Rails application:

1) Via
[claude-agent-sdk-ruby](https://github.com/ya-luotao/claude-agent-sdk-ruby), an
unofficial Ruby port of the Claude Agent Python SDK which spawns Node
subprocesses

2) Via
[claude-agent-sdk-typescript](https://github.com/anthropics/claude-agent-sdk-typescript),
the official TypeScript SDK, and a persistent sidecar Node process

3) Via [claude-code-acp](https://github.com/zed-industries/claude-code-acp), an
unofficial [Agent Client Protocol](https://agentclientprotocol.com) wrapper and
separate subprocesses

The spikes are documented in `./docs/`.

## Motivation

Claude Code is a very powerful framework for automation, not just for writing
code. There are many usecases where giving an LLM tool-use, filesystem access,
and permission to run and execute scripts vastly enhances its capabilities.

While the objective of this repo is to display a GUI that lets you chat to a
Claude Code-style interface directly, that's not the only way. You can spawn an
agent entirely in the background, using jobs/workers, and give it tools to read
and write to the database.

This spike is about finding the cleanest, most maintainable way to do so.

## Setup

This repo was generated with:

```sh
rails new claude-agent-rails-spike \
          -c tailwind \
          --skip-action-mailer \
          --skip-action-mailbox \
          --skip-action-text \
          --skip-jbuilder \
          --skip-kamal \
          --skip-docker \
          --skip-ci \
          --skip-test
```

To run:

```sh
cp mise.local.toml.example mise.local.toml
mise install
bin/setup
```

## Results

### Spike 1 (Claude Agent SDK Ruby)

![Claude Agent SDK Ruby](docs/spike-ruby-sdk-screenshot.png)

## License

[MIT](LICENSE).
