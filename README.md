# Markdown Reader

Visor nativo de Markdown para macOS, en SwiftUI. Pensado sobre todo para **leer**:
abre un `.md` con doble clic y lo muestra formateado, con la opción de ver y
editar el texto plano cuando hace falta.


## Qué hace

**Lectura**

- Render nativo (nada de WebView): títulos, listas anidadas, tablas con
  alineación, citas, avisos estilo GitHub (`> [!NOTE]`), imágenes locales y
  remotas, metadatos YAML, líneas horizontales y enlaces por referencia.
- Bloques de código con resaltado de sintaxis para ~30 lenguajes y botón de
  copiar al pasar el ratón.
- Índice lateral con filtro: al pulsar un título se salta a esa sección.
- Tipografía ajustable (sistema, serif, redondeada o monoespaciada), tamaño y
  ancho de línea configurables.
- Los enlaces internos (`#seccion`) hacen scroll; los enlaces a otros `.md`
  del mismo directorio abren una ventana nueva.
- Las casillas de las listas de tareas se pueden marcar desde la vista
  formateada: se escribe el cambio en el fichero.

**Edición**

- Vista de código fuente con numeración de líneas, resaltado del propio
  Markdown y búsqueda (⌘F). Las comillas tipográficas y demás sustituciones
  automáticas están desactivadas para no corromper el fichero.
- Guardado estándar del sistema (⌘S), con versiones y "deshacer" de macOS.
- Vista dividida con el render actualizándose mientras escribes.
- Exportación a HTML autocontenido (con estilos claro/oscuro) y "copiar como
  HTML".

## Compilar e instalar

```bash
./Scripts/build_app.sh --install
```

Eso compila en modo release, arma `Markdown Reader.app`, la firma en modo
ad-hoc y la copia a `/Applications`. Sin `--install` la deja en `build/`.
Otras opciones: `--debug`, `--universal` (arm64 + x86_64).

Para trabajar en el código:

```bash
swift build      # compilar
swift test       # 24 tests del parser, el documento y la exportación
```

## Ponerla como app por defecto

Desde la app: menú **Markdown Reader › Usar Markdown Reader para abrir los
.md**, o el botón que hay en Ajustes (⌘,). También se puede hacer desde el
Finder: clic derecho en un `.md` → Obtener información → *Abrir con* →
Markdown Reader → *Cambiar todos*.

> Conviene instalarla en `/Applications` antes de fijarla como predeterminada:
> si la app vive en un disco externo, la asociación se rompe al desmontarlo.

## Atajos

| Acción | Atajo |
|:-------|:------|
| Vista formateada | ⌘1 |
| Código fuente | ⌘2 |
| Vista dividida | ⌘3 |
| Mostrar/ocultar índice | ⌃⌘S |
| Aumentar / reducir texto | ⌘+ / ⌘− |
| Tamaño original | ⌘0 |
| Buscar (en el editor) | ⌘F |
| Guardar | ⌘S |
| Mostrar en el Finder | ⇧⌘R |

## Cómo está montado

```
Sources/MarkdownReader/
  App/        punto de entrada, menús, ajustes, app por defecto
  Model/      documento (FileDocument) y parser de bloques
  Render/     tipografía, estilo inline y resaltado de código
  Views/      vista formateada, editor y barra lateral
  Export/     serialización a HTML
AppResources/ Info.plist (tipos de documento) e icono
Scripts/      build_app.sh y generador del icono
```

El parseo va en dos capas: `MarkdownParser` resuelve la estructura de bloques
(lo que Foundation no expone) y el marcado *inline* (negritas, enlaces, código)
lo hace el parser de Markdown de Foundation dentro de `InlineRenderer`, que
además resuelve referencias y autoenlaces.

Requisitos: macOS 14 o posterior.
