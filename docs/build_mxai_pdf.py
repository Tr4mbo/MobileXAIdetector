from __future__ import annotations

from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    HRFlowable,
    ListFlowable,
    ListItem,
    PageBreak,
    Paragraph,
    Preformatted,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
PDF_PATH = ROOT / "docs" / "MXAI_Detector_Documentacion_Tecnica.pdf"

CYAN = colors.HexColor("#28D8D1")
DARK = colors.HexColor("#0B1720")
INK = colors.HexColor("#17232D")
MUTED = colors.HexColor("#5E6F78")
BLUE = colors.HexColor("#2E74B5")
BLUE_DARK = colors.HexColor("#1F4D78")
LINE = colors.HexColor("#D7E1E5")
SOFT = colors.HexColor("#F4F6F8")
FILL = colors.HexColor("#EFF7F8")
WARN = colors.HexColor("#FFF7E6")


def header_footer(canvas, doc):
    canvas.saveState()
    width, height = letter
    canvas.setStrokeColor(LINE)
    canvas.setLineWidth(0.5)
    canvas.line(doc.leftMargin, height - 0.55 * inch, width - doc.rightMargin, height - 0.55 * inch)
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(MUTED)
    canvas.drawString(doc.leftMargin, 0.45 * inch, "MXAI Detector - Documentacion tecnica")
    canvas.drawRightString(width - doc.rightMargin, 0.45 * inch, f"Pagina {doc.page}")
    canvas.restoreState()


def make_styles():
    base = getSampleStyleSheet()
    base.add(
        ParagraphStyle(
            name="CoverTitle",
            parent=base["Title"],
            fontName="Helvetica-Bold",
            fontSize=30,
            leading=34,
            textColor=colors.HexColor("#0B2545"),
            alignment=TA_LEFT,
            spaceAfter=8,
        )
    )
    base.add(
        ParagraphStyle(
            name="CoverSubtitle",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=14,
            leading=18,
            textColor=MUTED,
            alignment=TA_LEFT,
            spaceAfter=18,
        )
    )
    base.add(
        ParagraphStyle(
            name="Body",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=10.4,
            leading=14.2,
            spaceAfter=7,
        )
    )
    base.add(
        ParagraphStyle(
            name="H1x",
            parent=base["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=16,
            leading=20,
            textColor=BLUE,
            spaceBefore=16,
            spaceAfter=8,
            keepWithNext=True,
        )
    )
    base.add(
        ParagraphStyle(
            name="H2x",
            parent=base["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=13,
            leading=16,
            textColor=BLUE,
            spaceBefore=12,
            spaceAfter=6,
            keepWithNext=True,
        )
    )
    base.add(
        ParagraphStyle(
            name="H3x",
            parent=base["Heading3"],
            fontName="Helvetica-Bold",
            fontSize=11.5,
            leading=14,
            textColor=BLUE_DARK,
            spaceBefore=8,
            spaceAfter=4,
            keepWithNext=True,
        )
    )
    base.add(
        ParagraphStyle(
            name="Small",
            parent=base["Body"],
            fontName="Helvetica",
            fontSize=8.7,
            leading=11.2,
            textColor=MUTED,
        )
    )
    base.add(
        ParagraphStyle(
            name="CalloutTitle",
            parent=base["Body"],
            fontName="Helvetica-Bold",
            fontSize=10.5,
            leading=13,
            textColor=colors.HexColor("#0B3745"),
            spaceAfter=3,
        )
    )
    base.add(
        ParagraphStyle(
            name="TableText",
            parent=base["Body"],
            fontSize=9,
            leading=11.5,
            spaceAfter=0,
        )
    )
    base.add(
        ParagraphStyle(
            name="TableHead",
            parent=base["TableText"],
            fontName="Helvetica-Bold",
            textColor=colors.HexColor("#0B2545"),
        )
    )
    base.add(
        ParagraphStyle(
            name="CodeBlockText",
            parent=base["Code"],
            fontName="Courier",
            fontSize=8.7,
            leading=11.3,
            textColor=colors.HexColor("#E7F2F2"),
        )
    )
    return base


def P(styles, text: str, style: str = "Body") -> Paragraph:
    return Paragraph(text, styles[style])


def bullets(styles, items: list[str]) -> ListFlowable:
    return ListFlowable(
        [ListItem(P(styles, item), leftIndent=12) for item in items],
        bulletType="bullet",
        start="circle",
        leftIndent=16,
        bulletFontName="Helvetica",
        bulletFontSize=8,
        bulletColor=CYAN,
    )


def numbers(styles, items: list[str]) -> ListFlowable:
    return ListFlowable(
        [ListItem(P(styles, item), leftIndent=14) for item in items],
        bulletType="1",
        leftIndent=18,
        bulletFontName="Helvetica-Bold",
        bulletFontSize=9,
        bulletColor=BLUE,
    )


def callout(styles, title: str, body: str, fill=FILL) -> Table:
    data = [[P(styles, title, "CalloutTitle")], [P(styles, body)]]
    table = Table(data, colWidths=[6.5 * inch], hAlign="LEFT")
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), fill),
                ("BOX", (0, 0), (-1, -1), 0.8, LINE),
                ("LEFTPADDING", (0, 0), (-1, -1), 9),
                ("RIGHTPADDING", (0, 0), (-1, -1), 9),
                ("TOPPADDING", (0, 0), (-1, -1), 7),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
            ]
        )
    )
    return table


def kv_table(styles, rows: list[tuple[str, str]], col1=1.75, col2=4.75) -> Table:
    data = [[P(styles, "Elemento", "TableHead"), P(styles, "Descripcion", "TableHead")]]
    for left, right in rows:
        data.append([P(styles, left, "TableHead"), P(styles, right, "TableText")])
    table = Table(data, colWidths=[col1 * inch, col2 * inch], repeatRows=1, hAlign="LEFT")
    style = [
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E8EEF5")),
        ("GRID", (0, 0), (-1, -1), 0.45, LINE),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 7),
        ("RIGHTPADDING", (0, 0), (-1, -1), 7),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]
    for row_idx in range(1, len(data)):
        style.append(("BACKGROUND", (0, row_idx), (0, row_idx), colors.HexColor("#F2F4F7")))
    table.setStyle(TableStyle(style))
    return table


def code_block(styles, text: str) -> Table:
    table = Table([[Preformatted(text, styles["CodeBlockText"])]], colWidths=[6.5 * inch], hAlign="LEFT")
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), DARK),
                ("BOX", (0, 0), (-1, -1), 0.8, colors.HexColor("#24404A")),
                ("LEFTPADDING", (0, 0), (-1, -1), 9),
                ("RIGHTPADDING", (0, 0), (-1, -1), 9),
                ("TOPPADDING", (0, 0), (-1, -1), 7),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
            ]
        )
    )
    return table


def build_story():
    styles = make_styles()
    story = []

    story.append(P(styles, "MXAI Detector", "CoverTitle"))
    story.append(
        P(
            styles,
            "Documentacion tecnica del programa mobile de analisis Android con XAI",
            "CoverSubtitle",
        )
    )
    story.append(HRFlowable(width="100%", thickness=1.2, color=CYAN, spaceAfter=18))
    story.append(
        kv_table(
            styles,
            [
                ("Proyecto", "Mobile X AI Detector"),
                ("Plataforma", "Flutter + Android nativo + Ollama + backend Python opcional"),
                ("Modelo ML", "Android_Malwaredetector/android_malware_detector.joblib"),
                ("Fecha", "22 de mayo de 2026"),
            ],
            1.55,
            4.95,
        )
    )
    story.append(Spacer(1, 14))
    story.append(
        callout(
            styles,
            "Resumen",
            "MXAI Detector es una app Flutter orientada a analisis de comportamiento Android. "
            "La interfaz ejecuta un analisis global del dispositivo, recibe APKs externos por "
            "Android intents, muestra una decision Benign/Malware y usa Ollama para transformar "
            "probabilidades y factores locales en explicaciones legibles.",
        )
    )

    story.append(P(styles, "1. Proposito del programa", "H1x"))
    story.append(
        P(
            styles,
            "El programa combina deteccion de malware Android con explicabilidad. El usuario "
            "pulsa Analizar y el sistema observa apps, permisos y senales del dispositivo para "
            "producir un resultado global. Para APKs descargados, el flujo se activa fuera de "
            "la app mediante Compartir/Enviar a MXAI despues de la descarga.",
        )
    )
    story.append(
        P(
            styles,
            "La meta funcional final es conectar un extractor compatible con el modelo entrenado, "
            "producir un vector de 470 columnas y ejecutar android_malware_detector.joblib. En el "
            "estado actual, Flutter usa un motor prototipo calibrado y deja preparada una API Python "
            "para inferencia real con joblib.",
        )
    )

    story.append(P(styles, "2. Flujo conceptual de analisis", "H1x"))
    story.append(
        code_block(
            styles,
            "APK o comportamiento observado\n"
            "  -> Extractor de features compatible\n"
            "  -> Vector de 470 columnas\n"
            "  -> android_malware_detector.joblib\n"
            "  -> Prediccion Benign/Malware\n"
            "  -> SHAP / importancia local\n"
            "  -> Ollama explica el resultado",
        )
    )
    story.append(Spacer(1, 8))
    story.append(
        P(
            styles,
            "El punto central del flujo es la compatibilidad con las 470 columnas del modelo. "
            "La capa visual no decide por si sola: presenta la salida del motor de deteccion y "
            "separa la explicacion en dos funciones: reporte XAI del analisis global y chatbot "
            "defensivo de ciberseguridad.",
        )
    )

    story.append(P(styles, "3. Arquitectura general", "H1x"))
    story.append(
        kv_table(
            styles,
            [
                ("Flutter UI", "Pantallas, scanner circular, navbar lateral, reporte XAI, chatbot y ventana externa de APK."),
                ("Android nativo", "MethodChannel para listar apps instaladas, abrir ajustes de uso y recibir APKs compartidos."),
                ("Motor prototipo", "PrototypeDetectionEngine genera una decision temporal mientras se conecta el extractor real."),
                ("Modelo ML", "Metadata, features e importancia global se cargan como assets; el joblib queda para backend nativo/Python."),
                ("Ollama", "mxai-xai-report genera reportes; mxai-cyber-chat responde preguntas defensivas; mxai-tinyllama-local valida el GGUF."),
                ("Backend Python", "FastAPI recibe vector o diccionario de features, ejecuta joblib y devuelve probabilidades e importancia local."),
            ],
        )
    )

    story.append(P(styles, "4. Estructura de archivos principal", "H1x"))
    story.append(
        kv_table(
            styles,
            [
                ("lib/main.dart", "Interfaz principal, pantallas, navegacion lateral y paneles de analisis."),
                ("lib/models/detector_models.dart", "Modelos de datos: metadata, target, resultado y factores locales."),
                ("lib/services/detector_service.dart", "Motor temporal de deteccion y calibracion conservadora."),
                ("lib/services/android_app_scanner_service.dart", "Cliente Flutter del MethodChannel Android."),
                ("lib/services/ollama_service.dart", "Cliente HTTP hacia /api/generate de Ollama."),
                ("backend/inference_api.py", "Servidor FastAPI para ejecutar el modelo joblib con un vector compatible."),
                ("Android_Malwaredetector/", "Modelo entrenado, features, metricas, mapping de clases e importancias."),
                ("ollama/", "Modelfiles para reporte, chatbot y validacion del GGUF local."),
                ("scripts/", "Automatizacion para crear modelos Ollama e instalar el APK por ADB."),
            ],
        )
    )

    story.append(P(styles, "5. Interfaz movil", "H1x"))
    story.append(
        P(
            styles,
            "La app usa una estetica futurista oscura, con fondo plano de baja interferencia, "
            "scanner circular y paneles compactos. La navbar vertical se abre al tocar el escudo "
            "y desplaza ligeramente el contenido para mantener orientacion espacial.",
        )
    )
    story.append(
        bullets(
            styles,
            [
                "Inicio: analisis global, scanner circular, boton Analizar y reporte XAI.",
                "Decision: explica como decide el sistema y muestra el resultado actual.",
                "Datos: resume senales observadas, features y factores locales.",
                "Chat XAI: chatbot limitado a ciberseguridad defensiva y preguntas sobre MXAI.",
                "SDK Android: permisos, servicios y flujo externo para APK descargado.",
            ],
        )
    )

    story.append(P(styles, "6. Analisis global", "H1x"))
    story.append(
        P(
            styles,
            "El analisis global evita falsos positivos por volumen bruto de permisos. Android y "
            "los fabricantes preinstalan muchas apps con permisos sensibles; por eso el motor "
            "prototipo separa apps de usuario y apps de sistema/OEM, mide concentracion de senales "
            "y exige un umbral mas alto antes de marcar Malware.",
        )
    )
    story.append(
        bullets(
            styles,
            [
                "Si no hay senales fuertes, el riesgo global queda en rango Benign.",
                "Si varias apps de usuario concentran permisos y senales de alto riesgo, el resultado puede elevarse.",
                "El reporte XAI aparece en Inicio y usa solo los datos del analisis generado.",
            ],
        )
    )

    story.append(P(styles, "7. Analisis de APKs descargados", "H1x"))
    story.append(
        P(
            styles,
            "MXAI no compite con la descarga ni con el instalador del sistema. El manifest no "
            "declara ACTION_VIEW para APK; declara ACTION_SEND. Eso fuerza el flujo correcto: "
            "primero el usuario descarga el APK, despues lo comparte o envia a MXAI para analizarlo.",
        )
    )
    story.append(
        code_block(
            styles,
            "Descarga del APK\n"
            "  -> Compartir / Enviar a MXAI\n"
            "  -> Ventana externa de analisis\n"
            "  -> Decision + explicabilidad",
        )
    )

    story.append(PageBreak())
    story.append(P(styles, "8. Modelo ML y backend de inferencia", "H1x"))
    story.append(
        P(
            styles,
            "android_malware_detector.joblib es un modelo scikit-learn serializado. Dart/Flutter "
            "no puede ejecutarlo directamente de forma nativa. Por eso el proyecto mantiene dos "
            "caminos: un motor prototipo para la interfaz movil y una API Python para inferencia "
            "real cuando exista el vector de 470 features.",
        )
    )
    story.append(
        code_block(
            styles,
            "python -m pip install -r backend\\requirements.txt\n"
            "python -m uvicorn backend.inference_api:app --reload --host 127.0.0.1 --port 8000",
        )
    )
    story.append(
        P(
            styles,
            "El endpoint POST /predict acepta vector con 470 valores o un diccionario de features. "
            "Devuelve prediccion, probabilidades Benign/Malware e importancia local. Si SHAP esta "
            "disponible, usa TreeExplainer; si no, calcula una aproximacion con feature_importances_.",
        )
    )

    story.append(P(styles, "9. Ollama y XAI", "H1x"))
    story.append(
        P(
            styles,
            "La app llama a Ollama mediante HTTP en /api/generate. En telefono fisico, 127.0.0.1 "
            "apunta al telefono, no a la PC. Por eso el APK se compila con OLLAMA_BASE_URL apuntando "
            "a la IP local del equipo donde corre Ollama.",
        )
    )
    story.append(
        kv_table(
            styles,
            [
                ("mxai-xai-report", "Genera reporte del analisis global usando prediccion, probabilidades y factores locales."),
                ("mxai-cyber-chat", "Responde preguntas defensivas de ciberseguridad y sobre la app MXAI."),
                ("mxai-tinyllama-local", "Carga tinyllama.Q4_K_M.gguf como validacion de archivo local; no es el modelo activo si su salida es corrupta."),
            ],
        )
    )
    story.append(
        code_block(
            styles,
            ".\\scripts\\create_ollama_models.ps1\n"
            "$env:OLLAMA_HOST=\"0.0.0.0:11434\"\n"
            "ollama serve\n"
            ".\\scripts\\install_to_phone.ps1 -OllamaBaseUrl \"http://TU_IP_LOCAL:11434\"",
        )
    )
    story.append(
        callout(
            styles,
            "Nota practica sobre Ollama",
            "El APK no instala Ollama dentro de Android. Ollama corre como servidor externo en la PC "
            "o en otro host. Para una version 100% offline dentro del telefono, el siguiente paso seria "
            "integrar un runtime nativo como llama.cpp, ONNX Runtime o TFLite y cargar el modelo como asset compatible.",
            WARN,
        )
    )

    story.append(P(styles, "10. Permisos y servicios Android", "H1x"))
    story.append(
        kv_table(
            styles,
            [
                ("INTERNET", "Permite conectar con Ollama o con un backend de inferencia en la red local."),
                ("QUERY_ALL_PACKAGES", "Permite listar apps instaladas durante pruebas locales."),
                ("PACKAGE_USAGE_STATS", "Prepara acceso a estadisticas de uso; requiere activacion manual por el usuario."),
                ("ACTION_SEND APK", "Permite recibir APKs despues de descargarlos y compartirlos con MXAI."),
                ("AppAnalysisService", "Servicio reservado para analisis en segundo plano cuando se conecte el extractor real."),
            ],
        )
    )

    story.append(P(styles, "11. Instalacion y prueba", "H1x"))
    story.append(
        numbers(
            styles,
            [
                "Conectar el telefono por USB y activar depuracion USB.",
                "Crear los modelos Ollama con scripts\\create_ollama_models.ps1.",
                "Iniciar Ollama escuchando en red local con OLLAMA_HOST=0.0.0.0:11434.",
                "Instalar con scripts\\install_to_phone.ps1; el script detecta la IP local si no se pasa una manual.",
                "Abrir la app, ejecutar Analizar y despues generar el reporte XAI.",
            ],
        )
    )
    story.append(code_block(styles, "flutter analyze\nflutter test\nflutter build web\nflutter build apk --debug"))

    story.append(P(styles, "12. Estado actual y limitaciones", "H1x"))
    story.append(
        bullets(
            styles,
            [
                "La interfaz movil, navbar lateral, scanner, reporte XAI y chatbot ya estan implementados.",
                "El motor de Flutter sigue siendo prototipo hasta conectar el extractor de 470 columnas.",
                "El joblib se ejecuta desde backend Python o debera convertirse a ONNX/TFLite/plugin nativo.",
                "tinyllama.Q4_K_M.gguf se importa en Ollama, pero debe reemplazarse por una variante instruct/chat si devuelve salida corrupta.",
                "La reduccion de falsos positivos se basa en calibracion conservadora y separacion user/system apps.",
            ],
        )
    )

    story.append(P(styles, "13. Roadmap recomendado", "H1x"))
    story.append(
        numbers(
            styles,
            [
                "Construir extractor real que emita exactamente las 470 features esperadas.",
                "Conectar Flutter al backend /predict o portar el modelo a un formato movil.",
                "Agregar SHAP local real en la respuesta de inferencia y mapearlo al panel de Datos.",
                "Empaquetar una opcion offline de XAI con runtime nativo si se requiere funcionamiento sin PC.",
                "Endurecer permisos, privacidad y comunicacion de red antes de distribucion fuera de laboratorio.",
            ],
        )
    )

    story.append(P(styles, "14. Glosario breve", "H1x"))
    story.append(
        kv_table(
            styles,
            [
                ("APK", "Paquete instalable de Android."),
                ("Feature", "Variable numerica o categorica usada por el modelo."),
                ("Vector 470", "Entrada ordenada que el modelo entrenado espera recibir."),
                ("SHAP", "Tecnica de explicabilidad que estima contribuciones locales de features."),
                ("LLM", "Modelo de lenguaje usado para redactar explicaciones a partir de datos tecnicos."),
                ("Ollama", "Servidor local que ejecuta modelos de lenguaje y expone /api/generate."),
            ],
        )
    )

    return story


def main() -> None:
    PDF_PATH.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(PDF_PATH),
        pagesize=letter,
        rightMargin=1 * inch,
        leftMargin=1 * inch,
        topMargin=0.78 * inch,
        bottomMargin=0.72 * inch,
        title="MXAI Detector - Documentacion tecnica",
        author="MXAI Detector",
    )
    doc.build(build_story(), onFirstPage=header_footer, onLaterPages=header_footer)
    print(PDF_PATH)


if __name__ == "__main__":
    main()
