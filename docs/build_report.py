from pathlib import Path
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.colors import HexColor
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.pagesizes import A4

root = Path(__file__).resolve().parent
pdfmetrics.registerFont(TTFont('Segoe', 'C:/Windows/Fonts/segoeui.ttf'))
pdfmetrics.registerFont(TTFont('SegoeBold', 'C:/Windows/Fonts/segoeuib.ttf'))
body = ParagraphStyle('body', fontName='Segoe', fontSize=10, leading=14, textColor=HexColor('#213b3d'), spaceAfter=7)
heading = ParagraphStyle('heading', parent=body, fontName='SegoeBold', fontSize=11, spaceBefore=8)
title = ParagraphStyle('title', parent=heading, fontSize=24, leading=29, spaceAfter=14)
story = []
for line in (root / 'report.md').read_text(encoding='utf-8').splitlines():
    if not line.strip():
        continue
    if line.startswith('# '):
        story.append(Paragraph(line[2:], title))
    elif line.startswith('## '):
        story.append(Paragraph(line[3:], heading))
    elif line.startswith('[Проект'):
        story.append(Paragraph('<link href="https://github.com/DXaten/Quack" color="#14796d">Проект и исходники</link> / <link href="https://github.com/DXaten/Quack/releases/latest" color="#14796d">Windows-сборка</link> / <link href="https://github.com/DXaten/Quack/blob/main/media/quack-demo.mp4" color="#14796d">Видео</link>', body))
    else:
        story.append(Paragraph(line, body))
SimpleDocTemplate(str(root / 'report.pdf'), pagesize=A4, rightMargin=44, leftMargin=44, topMargin=35, bottomMargin=35).build(story)
