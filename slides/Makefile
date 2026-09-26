.PHONY: html pdf png watch clean help

# Makefile dedicato alla generazione delle slide v4 (tema custom Catppuccin/Inter).
# Uso: `make -C public/slides` oppure `make -C public/slides html`

SRC     ?= slides_v4.md
THEME   ?= theme-caw.css
OUT     ?= slides_v4.html
PDF_OUT ?= slides_v4.pdf
PNG_DIR ?= build/png
MARP     = npx --yes @marp-team/marp-cli@latest

help:
	@echo "Target disponibili:"
	@echo "  make html   - genera $(OUT) (default)"
	@echo "  make pdf    - genera $(PDF_OUT) (backup offline per il talk)"
	@echo "  make png    - esporta ogni slide come PNG in $(PNG_DIR)/ (per QA visivo)"
	@echo "  make watch  - server locale con live-reload (Ctrl+C per uscire)"
	@echo "  make clean  - rimuove PDF e i PNG generati (NON tocca $(OUT), è un deliverable versionato)"

html:
	$(MARP) --html --theme $(THEME) $(SRC) -o $(OUT)
	@echo "\n[OK] Slide HTML generate: $(OUT)"

pdf:
	$(MARP) --html --theme $(THEME) --pdf --allow-local-files $(SRC) -o $(PDF_OUT)
	@echo "\n[OK] Slide PDF generate: $(PDF_OUT)"

png:
	mkdir -p $(PNG_DIR)
	$(MARP) --html --theme $(THEME) --allow-local-files --images png $(SRC) -o $(PNG_DIR)/slide.png
	@echo "\n[OK] PNG generati in $(PNG_DIR)/"

watch:
	$(MARP) --html --theme $(THEME) --watch --server .

clean:
	rm -f $(PDF_OUT)
	rm -rf $(PNG_DIR)
	@echo "[OK] Puliti PDF e PNG generati (HTML lasciato intatto)."
