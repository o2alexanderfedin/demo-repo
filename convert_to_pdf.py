#!/usr/bin/env python3
"""
Convert Markdown report to PDF using Python libraries
"""
import subprocess
import sys
import os

def check_and_install_requirements():
    """Check and install required packages"""
    required_packages = ['markdown', 'pdfkit', 'beautifulsoup4']
    
    for package in required_packages:
        try:
            __import__(package)
        except ImportError:
            print(f"Installing {package}...")
            subprocess.check_call([sys.executable, "-m", "pip", "install", package])

def convert_md_to_pdf(input_file, output_file):
    """Convert markdown to PDF"""
    try:
        import markdown
        import pdfkit
        from bs4 import BeautifulSoup
        
        # Read markdown file
        with open(input_file, 'r', encoding='utf-8') as f:
            md_content = f.read()
        
        # Convert markdown to HTML
        html_content = markdown.markdown(md_content, extensions=['extra', 'codehilite', 'toc'])
        
        # Add CSS styling for better PDF output
        styled_html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {{
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    line-height: 1.6;
                    color: #1f2937;
                    max-width: 900px;
                    margin: 0 auto;
                    padding: 20px;
                }}
                h1, h2, h3 {{
                    color: #111827;
                    margin-top: 24px;
                }}
                h1 {{ font-size: 2.5em; text-align: center; }}
                h2 {{ font-size: 1.8em; border-bottom: 2px solid #e5e7eb; padding-bottom: 8px; }}
                h3 {{ font-size: 1.4em; }}
                table {{
                    border-collapse: collapse;
                    width: 100%;
                    margin: 20px 0;
                }}
                th, td {{
                    border: 1px solid #e5e7eb;
                    padding: 12px;
                    text-align: left;
                }}
                th {{
                    background-color: #f9fafb;
                    font-weight: bold;
                }}
                tr:nth-child(even) {{
                    background-color: #f9fafb;
                }}
                code {{
                    background-color: #f3f4f6;
                    padding: 2px 4px;
                    border-radius: 3px;
                    font-family: 'Courier New', monospace;
                }}
                pre {{
                    background-color: #f3f4f6;
                    padding: 16px;
                    border-radius: 8px;
                    overflow-x: auto;
                }}
                blockquote {{
                    border-left: 4px solid #3b82f6;
                    margin-left: 0;
                    padding-left: 16px;
                    color: #4b5563;
                }}
                .mermaid {{
                    text-align: center;
                    margin: 20px 0;
                }}
                strong {{
                    color: #111827;
                }}
                div[align="center"] {{
                    text-align: center;
                    margin: 20px 0;
                }}
            </style>
        </head>
        <body>
            {html_content}
        </body>
        </html>
        """
        
        # Convert HTML to PDF
        options = {
            'page-size': 'A4',
            'margin-top': '0.75in',
            'margin-right': '0.75in',
            'margin-bottom': '0.75in',
            'margin-left': '0.75in',
            'encoding': "UTF-8",
            'no-outline': None,
            'enable-local-file-access': None
        }
        
        pdfkit.from_string(styled_html, output_file, options=options)
        print(f"PDF successfully created: {output_file}")
        
    except Exception as e:
        print(f"Error creating PDF: {e}")
        print("\nAlternative: Creating HTML file instead...")
        
        # Create HTML as fallback
        html_file = output_file.replace('.pdf', '.html')
        with open(html_file, 'w', encoding='utf-8') as f:
            f.write(styled_html)
        print(f"HTML file created: {html_file}")
        print("You can open this in a browser and use 'Print to PDF' feature")

if __name__ == "__main__":
    input_md = "/Users/alexanderfedin/Projects/demo/AI-Developer-ROI-Report-2025.md"
    output_pdf = "/Users/alexanderfedin/Projects/demo/AI-Developer-ROI-Report-2025.pdf"
    
    print("Checking requirements...")
    check_and_install_requirements()
    
    print(f"Converting {input_md} to PDF...")
    convert_md_to_pdf(input_md, output_pdf)