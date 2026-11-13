import json
import os
import sys
from pathlib import Path

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.main import app

def generate_docs():
    output_dir = Path(__file__).resolve().parent.parent
    
    # 1. Generate OpenAPI JSON Specification
    schema = app.openapi()
    json_path = output_dir / "openapi.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(schema, f, indent=2, ensure_ascii=False)
    print(f"Generated Swagger / OpenAPI JSON at: {json_path}")

    # 2. Generate Standalone Offline Swagger UI HTML
    spec_json_str = json.dumps(schema, ensure_ascii=False)
    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Imago Pastoral AI API Documentation - Swagger UI</title>
  <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
  <link rel="icon" type="image/png" href="https://unpkg.com/swagger-ui-dist@5/favicon-32x32.png" sizes="32x32" />
  <link rel="icon" type="image/png" href="https://unpkg.com/swagger-ui-dist@5/favicon-16x16.png" sizes="16x16" />
  <style>
    html {{
      box-sizing: border-box;
      overflow: -moz-scrollbars-vertical;
      overflow-y: scroll;
    }}
    *, *:before, *:after {{
      box-sizing: inherit;
    }}
    body {{
      margin: 0;
      background: #0b0f19;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    }}
    .custom-header {{
      background: linear-gradient(135deg, #1e1b4b 0%, #312e81 50%, #4338ca 100%);
      color: white;
      padding: 24px 32px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 1px solid rgba(255,255,255,0.1);
    }}
    .custom-header h1 {{
      margin: 0;
      font-size: 24px;
      display: flex;
      align-items: center;
      gap: 12px;
    }}
    .custom-header p {{
      margin: 6px 0 0 0;
      color: #c7d2fe;
      font-size: 14px;
    }}
    .header-badge {{
      background: #4f46e5;
      padding: 4px 10px;
      border-radius: 999px;
      font-size: 12px;
      font-weight: bold;
    }}
    /* Dark theme tweaks for Swagger UI */
    .swagger-ui .topbar {{ display: none; }}
    .swagger-ui {{
      background: #f8fafc;
      padding-bottom: 40px;
    }}
  </style>
</head>
<body>
  <div class="custom-header">
    <div>
      <h1>🕊️ Imago Pastoral AI & Church Management API</h1>
      <p>Interactive Swagger API Specification for mobile client, audio pipeline, and web services</p>
    </div>
    <div>
      <span class="header-badge">v1.0.0 OpenAPI 3.1</span>
    </div>
  </div>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js" charset="UTF-8"></script>
  <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-standalone-preset.js" charset="UTF-8"></script>
  <script>
    window.onload = function() {{
      const spec = {spec_json_str};
      
      const ui = SwaggerUIBundle({{
        spec: spec,
        dom_id: '#swagger-ui',
        deepLinking: true,
        presets: [
          SwaggerUIBundle.presets.apis,
          SwaggerUIStandalonePreset
        ],
        plugins: [
          SwaggerUIBundle.plugins.DownloadUrl
        ],
        layout: "BaseLayout",
        defaultModelsExpandDepth: 2,
        defaultModelExpandDepth: 2,
        docExpansion: "list"
      }});
      window.ui = ui;
    }};
  </script>
</body>
</html>
"""
    html_path = output_dir / "swagger_documentation.html"
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html_content)
    print(f"Generated Standalone Swagger UI HTML at: {html_path}")

if __name__ == "__main__":
    generate_docs()
