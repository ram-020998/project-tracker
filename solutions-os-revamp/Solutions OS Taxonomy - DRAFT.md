# Background

This is a proposal for the Solutions flavor of PEngOS, defining AI-SDLC workflows and structured handshakes between Product and Engineering  
 

# Thought Process

1. Tools agnostic, supporting Kiro and Gemini, extendable to any future viable provider  
2. Global documented solutions governance and standards  
3. Context rich and focused knowledgebases for each product  
4. Unified configs like common MCPs  
5. Separation when needed: Product focused AI-Tooling separated from Engineering focused AI-Tooling  
6. Business domain artifacts adhering to known schemas to prevent drifting and more deterministic outcomes  
7. Leverage “Appian Atlas” pilot for Appian-AI assisted coding / or replace with better alternatives in the future

# Repo Structure

```
/
├── .gemini/                    # Global Gemini CLI configuration
│   └── commands/               # Custom tool and command definitions
│       └── global/             # Commands available across all contexts
├── .kiro/                      # Project-level Kiro orchestration & steering
├── @DOCS/                      # Shared documentation and standards
│   ├── schemas/                # Data and architectural schema definitions
│   └── standards/              # Coding and engineering guidelines
├── ai-framework/               # Core AI platform and framework logic
│   ├── Engineering/            # Technical-focused AI configurations
│   │   ├── .gemini/            # Engineering-specific AI commands
│   │   │   └── commands/       # Technical tool definitions
│   │   ├── .kiro/              # Engineering-specific agent behavior
│   │   │   ├── hooks/          # Lifecycle and event triggers
│   │   │   ├── powers/         # Specialized agent capabilities
│   │   │   └── skills/         # Complex procedural expertise
│   │   └── steering/           # Technical directives for AI agents
│   ├── Product/                # Product-focused AI configurations
│   │   ├── .gemini/            # Product-specific AI commands
│   │   │   └── commands/       # Business-logic tool definitions
│   │   ├── .kiro/              # Product-specific agent behavior
│   │   │   ├── hooks/          # Domain-specific event triggers
│   │   │   ├── powers/         # Functional business capabilities
│   │   │   └── skills/         # Product-specific workflows
│   │   └── steering/           # Product-level directives for AI agents
│   └── mcp-configs/            # Model Context Protocol (MCP) server settings for both
└── products/                   # Individual product implementations
│   ├── AIDC/          # Product Alpha development workspace
│   │   └── knowledge-base/     # Product-specific technical intelligence
│   │       ├── arch-decision-logs/ # Records of architectural choices
│   │       ├── domain/         # Domain-specific entities (personas, overviews, docs...etc)
│   │       ├── Competetive-analysis/         # 
│   │       ├── features/       # Functional specifications and implementations
│  │       └── src-appian-atlas/ # Integration source for Appian Atlas
│   └── GCW/           # Product Beta development workspace
│       └── knowledge-base/     # Product-specific technical intelligence
│           ├── arch-decision-logs/ # Records of architectural choices
│           ├── domain/         # Domain-specific entities (personas, overviews...etc)
│  │       ├── Competetive-analysis/         # 
│           ├── features/       # Functional specifications and implementations
│           └── src-appian-atlas/ # Integration source for Appian Atlas
└── utilities/                   # Utilities
    ├──refresh products models/  # Pull latest solutions code 
```

## Recursive Folder Descriptions

### Core Infrastructure

| Path | Purpose |
| :---- | :---- |
| `.gemini/` | Root for Gemini CLI configurations. |
| `.gemini/commands/` | Workspace-specific tool and command extensions. |
| `.gemini/commands/global/` | Tools that should be accessible throughout the entire repository. |
| `.kiro/` | Root for Kiro agent orchestration, controlling how agents interact with this workspace. |
| `@DOCS/` | Central repository for all system-wide documentation. |
| `@DOCS/schemas/` | Houses formal definitions for artifacts |
| `@DOCS/standards/` | Contains the "Source of Truth" for coding styles and architectural patterns. |

### AI Framework

| Path | Purpose |
| :---- | :---- |
| `ai-framework/` | The engine room for the AI-driven system. |
| `ai-framework/mcp-configs/` | Configuration for MCP servers for both Product and Engineering used to extend agent context. |
| `ai-framework/Engineering/` | The technical "brain" of the AI, containing low-level implementations. |
| `ai-framework/Engineering/steering/` | Foundational engineering rules that the AI must follow. |
| `ai-framework/Engineering/.kiro/` | Low-level agent behaviors (hooks, powers, skills) specific to engineering tasks. |
| `ai-framework/Product/` | The business "brain" of the AI, containing functional logic. |
| `ai-framework/Product/steering/` | High-level product rules and business objectives for the AI. |
| `ai-framework/Product/.kiro/` | Agent behaviors optimized for product management and feature delivery. |

### Products

| Path | Purpose |
| :---- | :---- |
| `products/` | The implementation layer where individual products are developed. |
| `product-*/knowledge-base/` | The localized "memory" and specification set for a specific product. |
| `.../arch-decision-logs/` | History of *Why* things were built a certain way for that product. |
| `.../domain/` | The specific business domain logic for this product, entities (personas, overviews...etc) |
| `.../features/` | Implementation and documentation of specific product features. |
| `.../src-appian-atlas/` | Specialized integration folder for mapping product logic to Appian Atlas. |

