#!/usr/bin/env python3
"""Post-process pandoc .docx output:
1. Add table borders (pandoc doesn't inherit from --reference-doc)
2. Colorize [TODO: ...] text in red + bold for visibility

Usage: python3 fix_table_borders.py input.docx output.docx
"""
import sys, os, re, shutil, tempfile
from zipfile import ZipFile

BORDER_XML = (
    '<w:tblBorders xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
    '<w:top w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
    '<w:left w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
    '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
    '<w:right w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
    '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
    '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
    '</w:tblBorders>'
)

def fix_borders(content):
    """Add borders to tables missing them."""
    def add_borders(match):
        tbl_pr = match.group(0)
        if 'w:tblBorders' not in tbl_pr:
            return tbl_pr.replace('</w:tblPr>', BORDER_XML + '</w:tblPr>')
        return tbl_pr

    content = re.sub(r'<w:tblPr>.*?</w:tblPr>', add_borders, content, flags=re.DOTALL)
    content = re.sub(
        r'(<w:tbl>)(?!\s*<w:tblPr>)',
        r'\1<w:tblPr>' + BORDER_XML + '</w:tblPr>',
        content
    )
    return content

def fix_todo_colors(content):
    """Find [TODO: ...] text runs and wrap them with red color + bold."""
    # Match w:t elements containing [TODO
    def colorize_todo(match):
        full = match.group(0)
        # Add red color and bold to the run properties
        rpr_red = '<w:rPr><w:b/><w:color w:val="CC0000"/></w:rPr>'
        # If there's already an rPr, inject color into it
        if '<w:rPr>' in full:
            full = re.sub(r'<w:rPr>', r'<w:rPr><w:b/><w:color w:val="CC0000"/>', full)
        else:
            # Add rPr before w:t
            full = full.replace('<w:t', rpr_red + '<w:t')
        return full

    # Find runs containing [TODO or TODO:
    content = re.sub(
        r'<w:r>(?:(?!</w:r>).)*?\[TODO[^<]*</w:t>\s*</w:r>',
        colorize_todo, content, flags=re.DOTALL
    )
    return content

def process(input_file, output_file):
    tmpdir = tempfile.mkdtemp()
    with ZipFile(input_file, 'r') as zin:
        zin.extractall(tmpdir)

    doc_path = os.path.join(tmpdir, 'word', 'document.xml')
    with open(doc_path, 'r') as f:
        content = f.read()

    content = fix_borders(content)
    content = fix_todo_colors(content)

    with open(doc_path, 'w') as f:
        f.write(content)

    with ZipFile(output_file, 'w') as zout:
        for root, dirs, files in os.walk(tmpdir):
            for file in files:
                filepath = os.path.join(root, file)
                arcname = os.path.relpath(filepath, tmpdir)
                zout.write(filepath, arcname)

    shutil.rmtree(tmpdir)

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f'Usage: {sys.argv[0]} input.docx output.docx')
        sys.exit(1)
    process(sys.argv[1], sys.argv[2])
