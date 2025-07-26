#!/usr/bin/env node

/**
 * Website Fetcher MCP Server
 * A general-purpose web scraping and content fetching tool using the Model Context Protocol (MCP).
 * Supports fetching content from any website with configurable options.
 */

// Load environment variables
require('dotenv').config();

const https = require('https');
const http = require('http');
const zlib = require('zlib');
const { URL } = require('url');
const cheerio = require('cheerio');
const { Readability } = require('@mozilla/readability');
const { JSDOM } = require('jsdom');

// MCP Server Implementation
class WebsiteFetcherMCPServer {

    constructor() {
        this.requestId = 0;
        this.defaultHeaders = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1'
        };
    }

    async makeRequest(url, options = {}) {
        return new Promise((resolve, reject) => {
            try {
                const parsedUrl = new URL(url);
                const isHttps = parsedUrl.protocol === 'https:';
                const client = isHttps ? https : http;
                
                const requestOptions = {
                    hostname: parsedUrl.hostname,
                    port: parsedUrl.port || (isHttps ? 443 : 80),
                    path: parsedUrl.pathname + parsedUrl.search,
                    method: options.method || 'GET',
                    headers: {
                        ...this.defaultHeaders,
                        ...options.headers
                    },
                    timeout: options.timeout || 30000
                };

                const req = client.request(requestOptions, (res) => {
                    let rawData = Buffer.alloc(0);
                    
                    res.on('data', (chunk) => {
                        rawData = Buffer.concat([rawData, chunk]);
                    });
                    
                    res.on('end', () => {
                        try {
                            let data;
                            const encoding = res.headers['content-encoding'];
                            
                            if (encoding === 'gzip') {
                                data = zlib.gunzipSync(rawData).toString('utf8');
                            } else if (encoding === 'deflate') {
                                data = zlib.inflateSync(rawData).toString('utf8');
                            } else if (encoding === 'br') {
                                data = zlib.brotliDecompressSync(rawData).toString('utf8');
                            } else {
                                data = rawData.toString('utf8');
                            }
                            
                            resolve({ 
                                status: res.statusCode, 
                                headers: res.headers,
                                data: data,
                                url: url
                            });
                        } catch (error) {
                            reject(new Error(`Decompression failed: ${error.message}`));
                        }
                    });
                });

                req.on('error', (error) => {
                    reject(new Error(`Request failed: ${error.message}`));
                });

                req.on('timeout', () => {
                    req.destroy();
                    reject(new Error('Request timeout'));
                });

                if (options.body) {
                    req.write(options.body);
                }

                req.end();
            } catch (error) {
                reject(new Error(`Invalid URL or request setup: ${error.message}`));
            }
        });
    }

    async handleInitialize(params) {
        return {
            protocolVersion: "2024-11-05",
            capabilities: {
                tools: {
                    listChanged: false
                },
                resources: {},
                prompts: {}
            },
            serverInfo: {
                name: "website-fetcher-mcp-server",
                version: "1.0.0"
            }
        };
    }

    async handleListTools() {
        return {
            tools: [
                {
                    name: "fetch_website",
                    description: "Fetch and retrieve the HTML content of a website",
                    inputSchema: {
                        type: "object",
                        properties: {
                            url: {
                                type: "string",
                                description: "The URL of the website to fetch"
                            }
                        },
                        required: ["url"]
                    }
                },
                {
                    name: "fetch_website_with_headers",
                    description: "Fetch website content with custom headers",
                    inputSchema: {
                        type: "object",
                        properties: {
                            url: {
                                type: "string",
                                description: "The URL of the website to fetch"
                            },
                            headers: {
                                type: "object",
                                description: "Custom headers to send with the request",
                                additionalProperties: {
                                    type: "string"
                                }
                            }
                        },
                        required: ["url"]
                    }
                },
                {
                    name: "fetch_api_endpoint",
                    description: "Fetch data from an API endpoint with configurable method and body",
                    inputSchema: {
                        type: "object",
                        properties: {
                            url: {
                                type: "string",
                                description: "The API endpoint URL"
                            },
                            method: {
                                type: "string",
                                description: "HTTP method (GET, POST, PUT, DELETE, etc.)",
                                default: "GET"
                            },
                            headers: {
                                type: "object",
                                description: "Custom headers to send with the request",
                                additionalProperties: {
                                    type: "string"
                                }
                            },
                            body: {
                                type: "string",
                                description: "Request body for POST/PUT requests"
                            }
                        },
                        required: ["url"]
                    }
                },
                {
                    name: "fetch_curated_content",
                    description: "Fetch and extract curated content from a website, removing ads, navigation, and other non-content elements",
                    inputSchema: {
                        type: "object",
                        properties: {
                            url: {
                                type: "string",
                                description: "The URL of the website to fetch"
                            },
                            extractionType: {
                                type: "string",
                                description: "Type of content to extract: 'article' for blog/news content, 'structured' for specific elements",
                                enum: ["article", "structured"],
                                default: "article"
                            },
                            selectors: {
                                type: "object",
                                description: "CSS selectors to extract specific elements when using 'structured' type",
                                properties: {
                                    title: { type: "string" },
                                    content: { type: "string" },
                                    metadata: { type: "array", items: { type: "string" } }
                                }
                            }
                        },
                        required: ["url"]
                    }
                }
            ]
        };
    }

    async handleCallTool(params) {
        const { name, arguments: args } = params;

        try {
            switch (name) {
                case "fetch_website":
                    return await this.fetchWebsite(args.url);
                case "fetch_website_with_headers":
                    return await this.fetchWebsiteWithHeaders(args.url, args.headers);
                case "fetch_api_endpoint":
                    return await this.fetchApiEndpoint(args.url, args.method, args.headers, args.body);
                case "fetch_curated_content":
                    return await this.fetchCuratedContent(
                        args.url,
                        args.extractionType,
                        args.selectors
                    );
                default:
                    throw new Error(`Unknown tool: ${name}`);
            }
        } catch (error) {
            return {
                content: [
                    {
                        type: "text",
                        text: `Error: ${error.message}`
                    }
                ],
                isError: true
            };
        }
    }

    async fetchWebsite(url) {
        const response = await this.makeRequest(url);

        if (response.status >= 200 && response.status < 300) {
            return {
                content: [
                    {
                        type: "text",
                        text: `Website content for ${url}:\n\n${response.data}`
                    }
                ],
                isError: false
            };
        } else {
            throw new Error(`Failed to fetch website: HTTP ${response.status}`);
        }
    }

    async fetchWebsiteWithHeaders(url, customHeaders = {}) {
        const response = await this.makeRequest(url, { headers: customHeaders });

        if (response.status >= 200 && response.status < 300) {
            return {
                content: [
                    {
                        type: "text",
                        text: `Website content for ${url} (with custom headers):\n\n${response.data}`
                    }
                ],
                isError: false
            };
        } else {
            throw new Error(`Failed to fetch website: HTTP ${response.status}`);
        }
    }

    async fetchApiEndpoint(url, method = 'GET', customHeaders = {}, body = null) {
        const options = {
            method: method,
            headers: customHeaders
        };

        if (body) {
            options.body = body;
        }

        const response = await this.makeRequest(url, options);

        if (response.status >= 200 && response.status < 300) {
            let responseText;
            try {
                // Try to parse as JSON for pretty formatting
                const jsonData = JSON.parse(response.data);
                responseText = JSON.stringify(jsonData, null, 2);
            } catch {
                // If not JSON, return as is
                responseText = response.data;
            }

            return {
                content: [
                    {
                        type: "text",
                        text: `API response from ${url}:\nStatus: ${response.status}\n\n${responseText}`
                    }
                ],
                isError: false
            };
        } else {
            throw new Error(`API request failed: HTTP ${response.status} - ${response.data}`);
        }
    }

    async extractArticleContent(html, url) {
        const dom = new JSDOM(html, { url });
        const reader = new Readability(dom.window.document);
        const article = reader.parse();
        
        return {
            title: article.title,
            content: article.textContent,
            excerpt: article.excerpt,
            siteName: article.siteName,
            byline: article.byline
        };
    }

    async extractStructuredContent(html, selectors) {
        const $ = cheerio.load(html);
        const result = {};
        
        if (selectors.title) {
            result.title = $(selectors.title).text().trim();
        }
        
        if (selectors.content) {
            result.content = $(selectors.content).text().trim();
        }
        
        if (selectors.metadata) {
            result.metadata = {};
            selectors.metadata.forEach(selector => {
                const el = $(selector);
                const key = el.attr('property') || el.attr('name') || selector;
                result.metadata[key] = el.text().trim() || el.attr('content');
            });
        }
        
        return result;
    }

    async fetchCuratedContent(url, extractionType = 'article', selectors = {}) {
        const response = await this.makeRequest(url);
        
        if (response.status >= 200 && response.status < 300) {
            let extractedContent;
            
            if (extractionType === 'article') {
                extractedContent = await this.extractArticleContent(response.data, url);
            } else {
                extractedContent = await this.extractStructuredContent(response.data, selectors);
            }
            
            return {
                content: [
                    {
                        type: "text",
                        text: JSON.stringify(extractedContent, null, 2)
                    }
                ],
                isError: false
            };
        } else {
            throw new Error(`Failed to fetch website: HTTP ${response.status}`);
        }
    }

    async handleRequest(request) {
        const { method, params } = request;

        switch (method) {
            case "initialize":
                return await this.handleInitialize(params);
            case "tools/list":
                return await this.handleListTools();
            case "tools/call":
                return await this.handleCallTool(params);
            default:
                throw new Error(`Unknown method: ${method}`);
        }
    }

    sendResponse(id, result) {
        const response = {
            jsonrpc: "2.0",
            id: id,
            result: result
        };
        process.stdout.write(JSON.stringify(response) + '\n');
    }

    sendError(id, error) {
        const response = {
            jsonrpc: "2.0",
            id: id,
            error: {
                code: -32603,
                message: error.message
            }
        };
        process.stdout.write(JSON.stringify(response) + '\n');
    }

    start() {
        process.stdin.setEncoding('utf8');
        process.stdin.on('readable', () => {
            let chunk;
            while (null !== (chunk = process.stdin.read())) {
                const lines = chunk.split('\n');
                for (const line of lines) {
                    if (line.trim()) {
                        try {
                            const request = JSON.parse(line);
                            this.handleRequest(request)
                                .then(result => this.sendResponse(request.id, result))
                                .catch(error => this.sendError(request.id, error));
                        } catch (error) {
                            // Invalid XML, ignore
                        }
                    }
                }
            }
        });
    }
}

// Start the MCP server
const server = new WebsiteFetcherMCPServer();
server.start();