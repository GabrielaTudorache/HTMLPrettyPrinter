# HTML Pretty Printer

A simple Bash script that formats HTML files with proper indentation.

## Features

- Formats HTML with consistent indentation (2 spaces)
- Handles void elements (like `<br>`, `<img>`, `<input>`)
- Preserves raw element content (`<script>`, `<style>`, `<pre>`, `<textarea>`)
- Supports HTML comments and DOCTYPE declarations
- Multiple output options

## Usage

```bash
./html_formatter.sh <input_file> [output_mode] [output_path]
```

### Output Modes

| Mode | Description |
|------|-------------|
| `stdout` | Print to terminal (default) |
| `inplace` | Overwrite the original file |
| `newfile` | Write to a new file (requires output_path) |

### Examples

```bash
# Print formatted HTML to terminal
./html_formatter.sh index.html

# Overwrite the original file
./html_formatter.sh index.html inplace

# Save to a new file
./html_formatter.sh index.html newfile formatted.html
```

## Requirements

- Bash shell
- Standard Unix utilities (`sed`, `cat`, `tr`)
