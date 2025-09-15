#!/usr/bin/env node

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { CallToolRequestSchema, ListToolsRequestSchema } = require('@modelcontextprotocol/sdk/types.js');
const { createClient } = require('@supabase/supabase-js');

// Supabase設定
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://jvluhjifihiuopqdwjll.supabase.co';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2bHVoamlmaWhpdW9wcWR3amxsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExNTc5OTEsImV4cCI6MjA2NjczMzk5MX0.WDTzIs73X8NHGFcIYFk4CN-7dH5tQT5l0Bd2uY6H9lc';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

class SupabaseMCPServer {
  constructor() {
    this.server = new Server(
      {
        name: 'supabase-mcp-server',
        version: '0.1.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupToolHandlers();
  }

  setupToolHandlers() {
    // ツール一覧を提供
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: [
          {
            name: 'supabase_select',
            description: 'Supabaseからデータを取得',
            inputSchema: {
              type: 'object',
              properties: {
                table: {
                  type: 'string',
                  description: 'テーブル名',
                },
                columns: {
                  type: 'string',
                  description: '取得する列（カンマ区切り、*で全列）',
                },
                filter: {
                  type: 'object',
                  description: 'フィルター条件',
                },
              },
              required: ['table'],
            },
          },
          {
            name: 'supabase_insert',
            description: 'Supabaseにデータを挿入',
            inputSchema: {
              type: 'object',
              properties: {
                table: {
                  type: 'string',
                  description: 'テーブル名',
                },
                data: {
                  type: 'object',
                  description: '挿入するデータ',
                },
              },
              required: ['table', 'data'],
            },
          },
          {
            name: 'supabase_update',
            description: 'Supabaseのデータを更新',
            inputSchema: {
              type: 'object',
              properties: {
                table: {
                  type: 'string',
                  description: 'テーブル名',
                },
                data: {
                  type: 'object',
                  description: '更新するデータ',
                },
                filter: {
                  type: 'object',
                  description: 'フィルター条件',
                },
              },
              required: ['table', 'data', 'filter'],
            },
          },
          {
            name: 'supabase_delete',
            description: 'Supabaseからデータを削除',
            inputSchema: {
              type: 'object',
              properties: {
                table: {
                  type: 'string',
                  description: 'テーブル名',
                },
                filter: {
                  type: 'object',
                  description: 'フィルター条件',
                },
              },
              required: ['table', 'filter'],
            },
          },
        ],
      };
    });

    // ツール実行ハンドラー
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'supabase_select':
            return await this.handleSelect(args);
          case 'supabase_insert':
            return await this.handleInsert(args);
          case 'supabase_update':
            return await this.handleUpdate(args);
          case 'supabase_delete':
            return await this.handleDelete(args);
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Error: ${error.message}`,
            },
          ],
        };
      }
    });
  }

  async handleSelect(args) {
    const { table, columns = '*', filter = {} } = args;
    
    let query = supabase.from(table).select(columns);
    
    // フィルター適用
    Object.entries(filter).forEach(([key, value]) => {
      query = query.eq(key, value);
    });
    
    const { data, error } = await query;
    
    if (error) throw error;
    
    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(data, null, 2),
        },
      ],
    };
  }

  async handleInsert(args) {
    const { table, data } = args;
    
    const { data: result, error } = await supabase
      .from(table)
      .insert(data)
      .select();
    
    if (error) throw error;
    
    return {
      content: [
        {
          type: 'text',
          text: `Inserted successfully: ${JSON.stringify(result, null, 2)}`,
        },
      ],
    };
  }

  async handleUpdate(args) {
    const { table, data, filter } = args;
    
    let query = supabase.from(table).update(data);
    
    // フィルター適用
    Object.entries(filter).forEach(([key, value]) => {
      query = query.eq(key, value);
    });
    
    const { data: result, error } = await query.select();
    
    if (error) throw error;
    
    return {
      content: [
        {
          type: 'text',
          text: `Updated successfully: ${JSON.stringify(result, null, 2)}`,
        },
      ],
    };
  }

  async handleDelete(args) {
    const { table, filter } = args;
    
    let query = supabase.from(table).delete();
    
    // フィルター適用
    Object.entries(filter).forEach(([key, value]) => {
      query = query.eq(key, value);
    });
    
    const { error } = await query;
    
    if (error) throw error;
    
    return {
      content: [
        {
          type: 'text',
          text: 'Deleted successfully',
        },
      ],
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('Supabase MCP server running on stdio');
  }
}

const server = new SupabaseMCPServer();
server.run().catch(console.error);

