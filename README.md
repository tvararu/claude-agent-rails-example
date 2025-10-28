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
mise install
bin/setup
```

## License

[MIT](LICENSE).
