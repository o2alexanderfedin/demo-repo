#!/usr/bin/env python3
"""
Convert Markdown report to PDF using weasyprint
"""
import subprocess
import sys
import os
import re

def install_weasyprint():
    """Install weasyprint"""
    print("Installing weasyprint...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "weasyprint", "markdown", "pygments"])

def convert_md_to_pdf(input_file, output_file):
    """Convert markdown to PDF using weasyprint"""
    try:
        import markdown
        from weasyprint import HTML, CSS
        
        # Read markdown file
        with open(input_file, 'r', encoding='utf-8') as f:
            md_content = f.read()
        
        # Remove mermaid blocks since they won't render in PDF
        md_content = re.sub(r'```mermaid.*?```', '[Diagram - See HTML version]', md_content, flags=re.DOTALL)
        
        # Convert markdown to HTML
        md = markdown.Markdown(extensions=['extra', 'codehilite', 'tables', 'toc'])
        html_content = md.convert(md_content)
        
        # Create styled HTML
        styled_html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                @page {{
                    size: A4;
                    margin: 2cm;
                }}
                body {{
                    font-family: 'Helvetica Neue', Arial, sans-serif;
                    line-height: 1.6;
                    color: #1f2937;
                    font-size: 11pt;
                }}
                h1 {{
                    font-size: 24pt;
                    color: #111827;
                    text-align: center;
                    margin: 40px 0 20px 0;
                    page-break-after: avoid;
                }}
                h2 {{
                    font-size: 18pt;
                    color: #1f2937;
                    margin-top: 30px;
                    margin-bottom: 15px;
                    border-bottom: 2px solid #e5e7eb;
                    padding-bottom: 8px;
                    page-break-after: avoid;
                }}
                h3 {{
                    font-size: 14pt;
                    color: #374151;
                    margin-top: 20px;
                    margin-bottom: 10px;
                    page-break-after: avoid;
                }}
                h4 {{
                    font-size: 12pt;
                    color: #4b5563;
                    margin-top: 15px;
                    margin-bottom: 8px;
                }}
                p {{
                    margin: 10px 0;
                    text-align: justify;
                }}
                table {{
                    border-collapse: collapse;
                    width: 100%;
                    margin: 20px 0;
                    font-size: 10pt;
                    page-break-inside: avoid;
                }}
                th, td {{
                    border: 1px solid #d1d5db;
                    padding: 8px 12px;
                    text-align: left;
                }}
                th {{
                    background-color: #f3f4f6;
                    font-weight: bold;
                    color: #111827;
                }}
                tr:nth-child(even) {{
                    background-color: #f9fafb;
                }}
                code {{
                    background-color: #f3f4f6;
                    padding: 2px 4px;
                    border-radius: 3px;
                    font-family: 'Courier New', monospace;
                    font-size: 9pt;
                }}
                pre {{
                    background-color: #f3f4f6;
                    padding: 12px;
                    border-radius: 6px;
                    overflow-x: auto;
                    font-size: 9pt;
                    line-height: 1.4;
                    page-break-inside: avoid;
                }}
                blockquote {{
                    border-left: 4px solid #3b82f6;
                    margin: 20px 0;
                    padding-left: 16px;
                    color: #4b5563;
                    font-style: italic;
                }}
                ul, ol {{
                    margin: 10px 0;
                    padding-left: 30px;
                }}
                li {{
                    margin: 5px 0;
                }}
                strong {{
                    color: #111827;
                    font-weight: bold;
                }}
                em {{
                    font-style: italic;
                }}
                hr {{
                    border: none;
                    border-top: 1px solid #e5e7eb;
                    margin: 30px 0;
                }}
                div[align="center"] {{
                    text-align: center;
                    margin: 20px 0;
                }}
                .page-break {{
                    page-break-after: always;
                }}
                .no-break {{
                    page-break-inside: avoid;
                }}
            </style>
        </head>
        <body>
            {html_content}
        </body>
        </html>
        """
        
        # Generate PDF
        HTML(string=styled_html).write_pdf(output_file)
        print(f"PDF successfully created: {output_file}")
        
        # Also save the HTML version
        html_file = output_file.replace('.pdf', '.html')
        with open(html_file, 'w', encoding='utf-8') as f:
            f.write(styled_html)
        print(f"HTML version also saved: {html_file}")
        
    except ImportError:
        print("WeasyPrint not found. Installing...")
        install_weasyprint()
        # Try again after installation
        convert_md_to_pdf(input_file, output_file)
    except Exception as e:
        print(f"Error: {e}")
        print("\nTip: Open the HTML file in Chrome/Safari and use Print > Save as PDF")

if __name__ == "__main__":
    input_md = "/Users/alexanderfedin/Projects/demo/AI-Developer-ROI-Report-2025.md"
    output_pdf = "/Users/alexanderfedin/Projects/demo/AI-Developer-ROI-Report-2025.pdf"
    
    convert_md_to_pdf(input_md, output_pdf)