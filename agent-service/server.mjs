import express from 'express';
import { query } from '@anthropic-ai/claude-agent-sdk';
import { railsDbServer } from './tools.mjs';

const app = express();
const PORT = process.env.AGENT_SERVICE_PORT || 3001;
const RAILS_ROOT = process.env.RAILS_ROOT || process.cwd();

app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'agent-service' });
});

app.post('/agent/query', async (req, res) => {
  const { message } = req.body;

  if (!message) {
    return res.status(400).json({ error: 'Message is required' });
  }

  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no');

  try {
    const agentQuery = query({
      prompt: message,
      options: {
        cwd: RAILS_ROOT,
        mcpServers: {
          'rails-db': railsDbServer
        },
        allowedTools: ['mcp__rails-db__check_schema'],
        includePartialMessages: true,
        maxTurns: 10
      }
    });

    for await (const msg of agentQuery) {
      const event = formatMessage(msg);
      if (event) {
        res.write(`data: ${JSON.stringify(event)}\n\n`);
      }
    }

    res.write('data: [DONE]\n\n');
    res.end();
  } catch (error) {
    console.error('Agent query error:', error);
    res.write(
      `data: ${JSON.stringify({
        type: 'error',
        content: error.message
      })}\n\n`
    );
    res.end();
  }
});

function formatMessage(msg) {
  if (msg.type === 'stream_event') {
    const event = msg.event;

    if (event.type === 'content_block_delta') {
      const delta = event.delta;
      if (delta.type === 'text_delta') {
        return {
          type: 'assistant_delta',
          content: delta.text
        };
      }
    }
    return null;
  }

  if (msg.type === 'assistant') {
    const textBlocks = msg.message.content.filter(b => b.type === 'text');
    if (textBlocks.length > 0) {
      return {
        type: 'assistant',
        content: textBlocks.map(b => b.text).join('\n')
      };
    }
    return null;
  }

  if (msg.type === 'result') {
    return {
      type: 'result',
      cost: msg.total_cost_usd,
      turns: msg.num_turns
    };
  }

  return null;
}

app.listen(PORT, () => {
  console.log(`Agent service listening on port ${PORT}`);
  console.log(`Rails root: ${RAILS_ROOT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});
