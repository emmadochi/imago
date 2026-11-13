import json
import os
import sys
from datetime import datetime
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
    PageBreak,
    KeepTogether,
    HRFlowable,
)
from reportlab.pdfgen import canvas

# Numbered canvas for "Page X of Y"
class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_number(num_pages)
            super().showPage()
        super().save()

    def draw_page_number(self, page_count):
        self.saveState()
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#64748B"))
        
        # Header (pages > 1)
        if self._pageNumber > 1:
            self.drawString(36, 11 * inch - 28, "Imago Pastoral AI — Swagger / OpenAPI Specification Reference")
            self.drawRightString(8.5 * inch - 36, 11 * inch - 28, "v1.0.0")
            self.setStrokeColor(colors.HexColor("#E2E8F0"))
            self.setLineWidth(0.5)
            self.line(36, 11 * inch - 32, 8.5 * inch - 36, 11 * inch - 32)
        
        # Footer
        self.setStrokeColor(colors.HexColor("#E2E8F0"))
        self.setLineWidth(0.5)
        self.line(36, 36, 8.5 * inch - 36, 36)
        
        self.drawString(36, 24, "CONFIDENTIAL & PROPRIETARY — IMAGO PASTORAL AI BACKEND")
        page_str = f"Page {self._pageNumber} of {page_count}"
        self.drawRightString(8.5 * inch - 36, 24, page_str)
        self.restoreState()


def generate_pdf():
    backend_dir = Path(__file__).resolve().parent.parent
    spec_path = backend_dir / "openapi.json"
    pdf_path = backend_dir / "Imago_API_Swagger_Documentation.pdf"
    
    with open(spec_path, "r", encoding="utf-8") as f:
        spec = json.load(f)
        
    doc = SimpleDocTemplate(
        str(pdf_path),
        pagesize=letter,
        leftMargin=36,
        rightMargin=36,
        topMargin=44,
        bottomMargin=44,
    )
    
    styles = getSampleStyleSheet()
    
    # Custom Palette
    c_primary = colors.HexColor("#1E1B4B")
    c_indigo = colors.HexColor("#4338CA")
    c_accent = colors.HexColor("#6366F1")
    c_slate = colors.HexColor("#334155")
    c_muted = colors.HexColor("#64748B")
    c_bg_light = colors.HexColor("#F8FAFC")
    c_border = colors.HexColor("#E2E8F0")
    
    # Method Colors
    method_colors = {
        "POST": colors.HexColor("#059669"),
        "GET": colors.HexColor("#2563EB"),
        "DELETE": colors.HexColor("#DC2626"),
        "PUT": colors.HexColor("#D97706"),
        "PATCH": colors.HexColor("#7C3AED"),
        "WS": colors.HexColor("#9333EA"),
    }
    
    # Custom Styles
    style_title = ParagraphStyle(
        "CoverTitle",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=24,
        leading=28,
        textColor=colors.white,
    )
    
    style_subtitle = ParagraphStyle(
        "CoverSub",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=11,
        leading=16,
        textColor=colors.HexColor("#C7D2FE"),
    )
    
    style_h1 = ParagraphStyle(
        "SectionH1",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=15,
        leading=19,
        textColor=c_primary,
        spaceBefore=14,
        spaceAfter=6,
    )
    
    style_h2 = ParagraphStyle(
        "TagH2",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=12,
        leading=16,
        textColor=c_indigo,
        spaceBefore=10,
        spaceAfter=4,
    )
    
    style_body = ParagraphStyle(
        "DocBody",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=9,
        leading=13,
        textColor=c_slate,
    )
    
    style_body_bold = ParagraphStyle(
        "DocBodyBold",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=9,
        leading=13,
        textColor=c_slate,
    )
    
    style_code = ParagraphStyle(
        "CodeText",
        parent=styles["Normal"],
        fontName="Courier",
        fontSize=8,
        leading=10,
        textColor=colors.HexColor("#0F172A"),
    )
    
    style_endpoint_path = ParagraphStyle(
        "EndpointPath",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=10,
        leading=13,
        textColor=c_primary,
    )
    
    story = []
    
    # ─── HEADER / BANNER ──────────────────────────────────────────────
    banner_data = [
        [
            Paragraph("🕊️ Imago Pastoral AI & Church Management API", style_title),
            Paragraph("<b>v1.0.0</b><br/><font size=8>OpenAPI 3.1.0</font>", ParagraphStyle("Badge", parent=style_subtitle, alignment=2))
        ],
        [
            Paragraph("Official Swagger API Reference Manual, Data Models & Endpoint Schemas", style_subtitle),
            Paragraph(f"<font size=8 color='#C7D2FE'>{datetime.now().strftime('%B %d, %Y')}</font>", ParagraphStyle("Date", parent=style_subtitle, alignment=2))
        ]
    ]
    banner_table = Table(banner_data, colWidths=[420, 120])
    banner_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), c_primary),
        ('PADDING', (0, 0), (-1, -1), 14),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 2),
        ('TOPPADDING', (0, 1), (-1, 1), 2),
    ]))
    story.append(banner_table)
    story.append(Spacer(1, 14))
    
    # ─── EXECUTIVE SPEC SUMMARY TABLE ────────────────────────────────
    paths = spec.get("paths", {})
    components = spec.get("components", {})
    schemas = components.get("schemas", {})
    tags_meta = spec.get("tags", [])
    
    total_endpoints = sum(len(v) for v in paths.values())
    
    meta_summary = [
        [
            Paragraph("<b>Server Base URL:</b>", style_body),
            Paragraph("<code>http://localhost:8000</code> / Production Cloud URL", style_body),
            Paragraph("<b>Total Endpoints:</b>", style_body),
            Paragraph(f"<b>{total_endpoints}</b> operations across {len(paths)} paths", style_body),
        ],
        [
            Paragraph("<b>Auth Mechanism:</b>", style_body),
            Paragraph("Bearer Token (Firebase Auth) / Admin Secret", style_body),
            Paragraph("<b>Schema Models:</b>", style_body),
            Paragraph(f"<b>{len(schemas)}</b> Pydantic data schemas", style_body),
        ],
        [
            Paragraph("<b>Interactive Docs:</b>", style_body),
            Paragraph("<code>/docs</code> (Swagger UI) &nbsp;|&nbsp; <code>/redoc</code> (ReDoc)", style_body),
            Paragraph("<b>AI Engines:</b>", style_body),
            Paragraph("Google Gemini 2.5 Flash + Pinecone Vector Index", style_body),
        ]
    ]
    meta_table = Table(meta_summary, colWidths=[110, 180, 100, 150])
    meta_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), c_bg_light),
        ('BOX', (0, 0), (-1, -1), 1, c_border),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, c_border),
        ('PADDING', (0, 0), (-1, -1), 6),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
    ]))
    story.append(meta_table)
    story.append(Spacer(1, 16))
    
    # ─── GROUP ENDPOINTS BY TAG ───────────────────────────────────────
    endpoints_by_tag = {}
    for path, methods in paths.items():
        for method, op in methods.items():
            if method.lower() not in ["get", "post", "put", "delete", "patch"]:
                continue
            tags = op.get("tags", ["General"])
            tag = tags[0] if tags else "General"
            endpoints_by_tag.setdefault(tag, []).append((method.upper(), path, op))
            
    # Sort tags to follow tags_metadata
    tag_order = [t["name"] for t in tags_meta]
    sorted_tags = sorted(endpoints_by_tag.keys(), key=lambda t: tag_order.index(t) if t in tag_order else 999)
    
    story.append(Paragraph("API Endpoints & Operations Reference", style_h1))
    story.append(HRFlowable(width="100%", thickness=1.5, color=c_indigo, spaceBefore=2, spaceAfter=12))
    
    for tag in sorted_tags:
        ops = endpoints_by_tag[tag]
        tag_desc = next((t.get("description", "") for t in tags_meta if t["name"] == tag), "")
        
        tag_header_data = [
            [
                Paragraph(f"<b>{tag}</b>", style_h2),
                Paragraph(f"<font color='#64748B'>{len(ops)} endpoint{'s' if len(ops) > 1 else ''}</font>", ParagraphStyle("Right", parent=style_body, alignment=2))
            ]
        ]
        if tag_desc:
            tag_header_data.append([
                Paragraph(f"<i>{tag_desc}</i>", style_body),
                Paragraph("", style_body)
            ])
            
        t_header = Table(tag_header_data, colWidths=[420, 120])
        t_header.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor("#EEF2F6")),
            ('PADDING', (0, 0), (-1, -1), 6),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('SPAN', (0, 1), (1, 1)) if tag_desc else ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ]))
        story.append(KeepTogether([t_header, Spacer(1, 6)]))
        
        for method, path, op in ops:
            summary = op.get("summary", "")
            description = op.get("description", "")
            m_color = method_colors.get(method, c_slate)
            
            # Badge & Path Row
            endpoint_header = [
                [
                    Paragraph(f"<b><font color='white'>{method}</font></b>", ParagraphStyle("MBadge", parent=style_body, fontName="Helvetica-Bold", fontSize=9, alignment=1)),
                    Paragraph(f"<b>{path}</b>", style_endpoint_path),
                ]
            ]
            t_ep_head = Table(endpoint_header, colWidths=[65, 475])
            t_ep_head.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (0, 0), m_color),
                ('BACKGROUND', (1, 0), (1, 0), colors.HexColor("#F1F5F9")),
                ('PADDING', (0, 0), (-1, -1), 5),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('BOX', (0, 0), (-1, -1), 0.8, c_border),
            ]))
            
            detail_rows = []
            if summary:
                detail_rows.append([Paragraph("<b>Summary:</b>", style_body_bold), Paragraph(summary, style_body)])
            if description and description != summary:
                detail_rows.append([Paragraph("<b>Description:</b>", style_body_bold), Paragraph(description.replace("\n", "<br/>"), style_body)])
                
            # Request Parameters
            params = op.get("parameters", [])
            if params:
                param_strs = []
                for p in params:
                    req_mark = " <font color='red'>*required</font>" if p.get("required") else ""
                    p_type = p.get("schema", {}).get("type", "string")
                    param_strs.append(f"• <b>{p['name']}</b> ({p.get('in', 'query')}, <i>{p_type}</i>){req_mark}: {p.get('description', '')}")
                detail_rows.append([Paragraph("<b>Parameters:</b>", style_body_bold), Paragraph("<br/>".join(param_strs), style_body)])
                
            # Request Body
            req_body = op.get("requestBody", {})
            if req_body:
                content = req_body.get("content", {})
                for mime, m_obj in content.items():
                    schema_ref = m_obj.get("schema", {})
                    ref_name = schema_ref.get("$ref", "").split("/")[-1]
                    if ref_name:
                        detail_rows.append([Paragraph("<b>Payload Schema:</b>", style_body_bold), Paragraph(f"<code>{ref_name}</code> (JSON body)", style_body)])
                    elif schema_ref.get("properties"):
                        props = []
                        for prop_k, prop_v in schema_ref.get("properties", {}).items():
                            p_type = prop_v.get("type", "any")
                            props.append(f"• <b>{prop_k}</b>: <i>{p_type}</i>")
                        detail_rows.append([Paragraph("<b>Form / Body:</b>", style_body_bold), Paragraph("<br/>".join(props), style_body)])
                        
            # Responses
            resps = op.get("responses", {})
            if resps:
                resp_strs = []
                for code, r_obj in resps.items():
                    r_desc = r_obj.get("description", "")
                    r_content = r_obj.get("content", {}).get("application/json", {}).get("schema", {})
                    r_ref = r_content.get("$ref", "").split("/")[-1]
                    ref_suffix = f" → <code>{r_ref}</code>" if r_ref else ""
                    color_code = "#059669" if code.startswith("2") else "#DC2626"
                    resp_strs.append(f"<font color='{color_code}'><b>[{code}]</b></font> {r_desc}{ref_suffix}")
                detail_rows.append([Paragraph("<b>Responses:</b>", style_body_bold), Paragraph("<br/>".join(resp_strs), style_body)])
                
            t_ep_details = Table(detail_rows, colWidths=[95, 445])
            t_ep_details.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, -1), colors.white),
                ('BOX', (0, 0), (-1, -1), 0.8, c_border),
                ('INNERGRID', (0, 0), (-1, -1), 0.4, colors.HexColor("#F1F5F9")),
                ('PADDING', (0, 0), (-1, -1), 5),
                ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ]))
            
            story.append(KeepTogether([t_ep_head, t_ep_details, Spacer(1, 8)]))
            
        story.append(Spacer(1, 6))
        
    # ─── DATA MODELS / SCHEMAS SECTION ───────────────────────────────
    story.append(PageBreak())
    story.append(Paragraph("Pydantic Data Models & Schemas", style_h1))
    story.append(Paragraph("Complete structural field mapping of all incoming requests and outgoing API response models.", style_body))
    story.append(HRFlowable(width="100%", thickness=1.5, color=c_indigo, spaceBefore=4, spaceAfter=12))
    
    for schema_name, s_obj in sorted(schemas.items()):
        props = s_obj.get("properties", {})
        required_fields = s_obj.get("required", [])
        
        s_title_data = [[
            Paragraph(f"<b>Model: {schema_name}</b>", style_endpoint_path),
            Paragraph(f"<font color='#64748B'>{len(props)} properties</font>", ParagraphStyle("R", parent=style_body, alignment=2))
        ]]
        t_s_head = Table(s_title_data, colWidths=[400, 140])
        t_s_head.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor("#F1F5F9")),
            ('PADDING', (0, 0), (-1, -1), 5),
            ('BOX', (0, 0), (-1, -1), 0.8, c_border),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ]))
        
        prop_rows = [
            [
                Paragraph("<b>Property</b>", style_body_bold),
                Paragraph("<b>Type</b>", style_body_bold),
                Paragraph("<b>Required</b>", style_body_bold),
                Paragraph("<b>Description / Default</b>", style_body_bold),
            ]
        ]
        
        for p_name, p_val in props.items():
            p_type = p_val.get("type", "any")
            if "$ref" in p_val:
                p_type = p_val["$ref"].split("/")[-1]
            elif p_val.get("anyOf"):
                types = [x.get("type", x.get("$ref", "").split("/")[-1]) for x in p_val["anyOf"]]
                p_type = " | ".join(filter(None, types))
                
            is_req = p_name in required_fields
            req_str = "<font color='#DC2626'>Yes</font>" if is_req else "<font color='#64748B'>Optional</font>"
            
            p_desc = p_val.get("description", "")
            p_default = p_val.get("default", "")
            desc_parts = []
            if p_desc:
                desc_parts.append(p_desc)
            if p_default not in ["", None]:
                desc_parts.append(f"Default: <code>{p_default}</code>")
            final_desc = "<br/>".join(desc_parts) if desc_parts else "—"
            
            prop_rows.append([
                Paragraph(f"<b>{p_name}</b>", style_body),
                Paragraph(f"<code>{p_type}</code>", style_code),
                Paragraph(req_str, style_body),
                Paragraph(final_desc, style_body),
            ])
            
        t_s_body = Table(prop_rows, colWidths=[120, 120, 70, 230])
        t_s_body.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#F8FAFC")),
            ('BOX', (0, 0), (-1, -1), 0.8, c_border),
            ('INNERGRID', (0, 0), (-1, -1), 0.4, colors.HexColor("#F1F5F9")),
            ('PADDING', (0, 0), (-1, -1), 4),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ]))
        
        story.append(KeepTogether([t_s_head, t_s_body, Spacer(1, 10)]))
        
    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"Generated Swagger API PDF at: {pdf_path}")

if __name__ == "__main__":
    generate_pdf()
