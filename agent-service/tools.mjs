import { createSdkMcpServer, tool } from '@anthropic-ai/claude-agent-sdk';

const RAILS_API_URL = process.env.RAILS_API_URL || 'http://localhost:3000';

export const railsDbServer = createSdkMcpServer({
  name: 'rails-db',
  version: '1.0.0',
  tools: [
    tool(
      'check_schema',
      'Check database schema - returns list of tables and count',
      {},
      async () => {
        try {
          const response = await fetch(`${RAILS_API_URL}/api/schema`);

          if (!response.ok) {
            throw new Error(
              `Rails API error: ${response.status} ${response.statusText}`
            );
          }

          const data = await response.json();

          return {
            content: [{
              type: 'text',
              text: `Tables: ${data.tables.join(', ')}\nCount: ${data.count}`
            }]
          };
        } catch (error) {
          return {
            content: [{
              type: 'text',
              text: `Error calling Rails API: ${error.message}`
            }],
            isError: true
          };
        }
      }
    )
  ]
});
