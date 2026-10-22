#!/usr/bin/env python3
"""officefix.py DIR [MINUTES.png]: small, valid office documents for the thumbnail fixtures, as an office
suite would save them but without a preview inside, except Minutes.odt, which carries MINUTES.png as
LibreOffice's Thumbnails/thumbnail.png: Report.docx, Budget.xlsx, Pitch.pptx, Minutes.odt, Plan.ods, Talk.odp."""
import os
import sys
import zipfile
from xml.sax.saxutils import escape

D = sys.argv[1]
os.makedirs(D, exist_ok=True)
X = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'


def write(path, parts, mimetype=None):
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        if mimetype:  # ODF: first and stored
            z.writestr(zipfile.ZipInfo("mimetype"), mimetype, compress_type=zipfile.ZIP_STORED)
        for name, data in parts.items():
            z.writestr(name, data)


# ---- Word -------------------------------------------------------------------------------------------
W = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'


def para(text, size=22, bold=False, color="1F1F1F", after=160):
    b = "<w:b/>" if bold else ""
    return (f'<w:p><w:pPr><w:spacing w:after="{after}"/></w:pPr><w:r><w:rPr>{b}<w:color w:val="{color}"/>'
            f'<w:sz w:val="{size}"/></w:rPr><w:t xml:space="preserve">{escape(text)}</w:t></w:r></w:p>')


def docx(path, paras, thumb=None):
    body = "".join(paras)
    types = ('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
             '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
             '<Default Extension="xml" ContentType="application/xml"/>'
             + ('<Default Extension="jpeg" ContentType="image/jpeg"/><Default Extension="png" ContentType="image/png"/>' if thumb else "")
             + '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
             '</Types>')
    rels = ('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
            + ('<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/thumbnail" Target="docProps/thumbnail.png"/>' if thumb else "")
            + '</Relationships>')
    doc = (f'<w:document {W}><w:body>{body}<w:sectPr><w:pgSz w:w="12240" w:h="15840"/>'
           '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr></w:body></w:document>')
    parts = {"[Content_Types].xml": X + types, "_rels/.rels": X + rels, "word/document.xml": X + doc}
    if thumb:
        parts["docProps/thumbnail.png"] = open(thumb, "rb").read()
    write(path, parts)


LOREM = ("The survey covered twelve plots along the north ridge between September and October. "
         "Each plot was visited three times, and canopy cover, soil moisture and seedling counts "
         "were taken at fixed points marked on the first visit.")
docx(os.path.join(D, "Report.docx"), [
    para("Quarterly Report", 48, True, "2A6DF4", 240),
    para("Field station, autumn", 26, False, "6B6B6B", 320),
    para("Summary", 30, True),
    para(LOREM), para(LOREM),
    para("Findings", 30, True),
    para("Moisture fell on every plot after the second visit, most on the exposed east side. "
         "Seedling counts held steady, and two new species were recorded near plot 9."),
    para(LOREM),
])

# ---- Excel ------------------------------------------------------------------------------------------
rows = [["Item", "Q1", "Q2", "Q3", "Q4"], ["Rent", 1200, 1200, 1250, 1250], ["Travel", 340, 120, 610, 90],
        ["Equipment", 900, 0, 150, 420], ["Software", 80, 80, 95, 95], ["Total", 2520, 1400, 2105, 1855]]


def col(i):
    return "ABCDEFGHIJ"[i]


cells = ""
for r, row in enumerate(rows, 1):
    cells += f'<row r="{r}">'
    for c, v in enumerate(row):
        ref = f"{col(c)}{r}"
        style = ' s="1"' if r == 1 or r == len(rows) else ""
        if isinstance(v, str):
            cells += f'<c r="{ref}" t="inlineStr"{style}><is><t>{escape(v)}</t></is></c>'
        else:
            cells += f'<c r="{ref}"{style}><v>{v}</v></c>'
    cells += "</row>"
S = 'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"'
R = 'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"'
write(os.path.join(D, "Budget.xlsx"), {
    "[Content_Types].xml": X + '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>',
    "_rels/.rels": X + '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    "xl/workbook.xml": X + f'<workbook {S} {R}><sheets><sheet name="Budget" sheetId="1" r:id="rId1"/></sheets></workbook>',
    "xl/_rels/workbook.xml.rels": X + '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>',
    "xl/styles.xml": X + f'<styleSheet {S}><fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border/></borders>'
    '<cellStyleXfs count="1"><xf/></cellStyleXfs><cellXfs count="2"><xf/><xf fontId="1" applyFont="1"/></cellXfs></styleSheet>',
    "xl/worksheets/sheet1.xml": X + f'<worksheet {S}><sheetData>{cells}</sheetData></worksheet>',
})

# ---- PowerPoint -------------------------------------------------------------------------------------
P = ('xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
     'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
     'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"')
RELS = 'xmlns="http://schemas.openxmlformats.org/package/2006/relationships"'
RT = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/"
TREE = ('<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
        '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>')


def box(i, x, y, w, h, text, size, bold, color):
    b = ' b="1"' if bold else ""
    return (f'<p:sp><p:nvSpPr><p:cNvPr id="{i}" name="Text {i}"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>'
            f'<p:spPr><a:xfrm><a:off x="{x}" y="{y}"/><a:ext cx="{w}" cy="{h}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>'
            f'<p:txBody><a:bodyPr wrap="square"/><a:lstStyle/><a:p><a:r><a:rPr lang="en-US" sz="{size}"{b}>'
            f'<a:solidFill><a:srgbClr val="{color}"/></a:solidFill></a:rPr><a:t>{escape(text)}</a:t></a:r></a:p></p:txBody></p:sp>')


band = ('<p:sp><p:nvSpPr><p:cNvPr id="9" name="Band"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="0" y="0"/>'
        '<a:ext cx="12192000" cy="6858000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
        '<a:solidFill><a:srgbClr val="1E3A8A"/></a:solidFill></p:spPr></p:sp>')
slide = (f'<p:sld {P}><p:cSld><p:spTree>{TREE}{band}'
         + box(2, 900000, 2300000, 10400000, 1300000, "Ridge Survey 2026", 6000, True, "FFFFFF")
         + box(3, 900000, 3700000, 10400000, 700000, "Twelve plots, three visits, one autumn", 2800, False, "C7D2FE")
         + '</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>')
theme = ('<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office"><a:themeElements>'
         '<a:clrScheme name="Office"><a:dk1><a:srgbClr val="000000"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>'
         '<a:dk2><a:srgbClr val="44546A"/></a:dk2><a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>'
         + "".join(f'<a:accent{i}><a:srgbClr val="{c}"/></a:accent{i}>' for i, c in
                   enumerate(["4472C4", "ED7D31", "A5A5A5", "FFC000", "5B9BD5", "70AD47"], 1))
         + '<a:hlink><a:srgbClr val="0563C1"/></a:hlink><a:folHlink><a:srgbClr val="954F72"/></a:folHlink></a:clrScheme>'
         '<a:fontScheme name="Office"><a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>'
         '<a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont></a:fontScheme>'
         '<a:fmtScheme name="Office"><a:fillStyleLst>' + '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>' * 3
         + '</a:fillStyleLst><a:lnStyleLst>' + '<a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>' * 3
         + '</a:lnStyleLst><a:effectStyleLst>' + '<a:effectStyle><a:effectLst/></a:effectStyle>' * 3
         + '</a:effectStyleLst><a:bgFillStyleLst>' + '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>' * 3
         + '</a:bgFillStyleLst></a:fmtScheme></a:themeElements></a:theme>')
write(os.path.join(D, "Pitch.pptx"), {
    "[Content_Types].xml": X + '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>'
    '<Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>'
    '<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>'
    '<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>'
    '<Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/></Types>',
    "_rels/.rels": X + f'<Relationships {RELS}><Relationship Id="rId1" Type="{RT}officeDocument" Target="ppt/presentation.xml"/></Relationships>',
    "ppt/presentation.xml": X + f'<p:presentation {P}><p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>'
    '<p:sldIdLst><p:sldId id="256" r:id="rId2"/></p:sldIdLst><p:sldSz cx="12192000" cy="6858000"/><p:notesSz cx="6858000" cy="9144000"/></p:presentation>',
    "ppt/_rels/presentation.xml.rels": X + f'<Relationships {RELS}><Relationship Id="rId1" Type="{RT}slideMaster" Target="slideMasters/slideMaster1.xml"/>'
    f'<Relationship Id="rId2" Type="{RT}slide" Target="slides/slide1.xml"/><Relationship Id="rId3" Type="{RT}theme" Target="theme/theme1.xml"/></Relationships>',
    "ppt/slides/slide1.xml": X + slide,
    "ppt/slides/_rels/slide1.xml.rels": X + f'<Relationships {RELS}><Relationship Id="rId1" Type="{RT}slideLayout" Target="../slideLayouts/slideLayout1.xml"/></Relationships>',
    "ppt/slideLayouts/slideLayout1.xml": X + f'<p:sldLayout {P}><p:cSld><p:spTree>{TREE}</p:spTree></p:cSld>'
    '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>',
    "ppt/slideLayouts/_rels/slideLayout1.xml.rels": X + f'<Relationships {RELS}><Relationship Id="rId1" Type="{RT}slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>',
    "ppt/slideMasters/slideMaster1.xml": X + f'<p:sldMaster {P}><p:cSld><p:spTree>{TREE}</p:spTree></p:cSld>'
    '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" '
    'accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>'
    '<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst></p:sldMaster>',
    "ppt/slideMasters/_rels/slideMaster1.xml.rels": X + f'<Relationships {RELS}><Relationship Id="rId1" Type="{RT}slideLayout" Target="../slideLayouts/slideLayout1.xml"/>'
    f'<Relationship Id="rId2" Type="{RT}theme" Target="../theme/theme1.xml"/></Relationships>',
    "ppt/theme/theme1.xml": X + theme,
})

# ---- OpenDocument -----------------------------------------------------------------------------------
NS = ('xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
      'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0" '
      'xmlns:presentation="urn:oasis:names:tc:opendocument:xmlns:presentation:1.0" xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0" '
      'xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" '
      'xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" office:version="1.3"')


def odf(path, mime, body, thumb=None):
    manifest = (f'<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.3">'
                f'<manifest:file-entry manifest:full-path="/" manifest:media-type="{mime}"/>'
                '<manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>'
                + ('<manifest:file-entry manifest:full-path="Thumbnails/thumbnail.png" manifest:media-type="image/png"/>' if thumb else "")
                + '</manifest:manifest>')
    parts = {"content.xml": X + f'<office:document-content {NS}><office:body>{body}</office:body></office:document-content>',
             "META-INF/manifest.xml": X + manifest}
    if thumb:
        parts["Thumbnails/thumbnail.png"] = open(thumb, "rb").read()
    write(path, parts, mimetype=mime)


odf(os.path.join(D, "Minutes.odt"), "application/vnd.oasis.opendocument.text",
    '<office:text><text:h text:outline-level="1">Minutes, 14 October</text:h>'
    f'<text:p>Present: Robin, Sam, Ade, Mei.</text:p><text:p>{escape(LOREM)}</text:p>'
    '<text:h text:outline-level="2">Actions</text:h><text:p>Sam books the boat; Mei orders seed trays.</text:p></office:text>',
    thumb=sys.argv[2] if len(sys.argv) > 2 else None)
cells = "".join("<table:table-row>" + "".join(
    f'<table:table-cell office:value-type="float" office:value="{v}"><text:p>{v}</text:p></table:table-cell>' if not isinstance(v, str)
    else f'<table:table-cell office:value-type="string"><text:p>{escape(v)}</text:p></table:table-cell>' for v in row)
    + "</table:table-row>" for row in rows)
odf(os.path.join(D, "Plan.ods"), "application/vnd.oasis.opendocument.spreadsheet",
    f'<office:spreadsheet><table:table table:name="Plan"><table:table-column table:number-columns-repeated="5"/>{cells}</table:table></office:spreadsheet>')
odf(os.path.join(D, "Talk.odp"), "application/vnd.oasis.opendocument.presentation",
    '<office:presentation><draw:page draw:name="1">'
    '<draw:frame svg:x="2cm" svg:y="6cm" svg:width="24cm" svg:height="3cm"><draw:text-box><text:p>Seedlings after the dry spell</text:p></draw:text-box></draw:frame>'
    '<draw:frame svg:x="2cm" svg:y="9.5cm" svg:width="24cm" svg:height="2cm"><draw:text-box><text:p>Notes from plot 9</text:p></draw:text-box></draw:frame>'
    '</draw:page></office:presentation>')
print("officefix:", sorted(os.listdir(D)))
