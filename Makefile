.PHONY: slides slides-pdf slides-watch

# Sorgente slide e output
SLIDES_SRC ?= slides/slides_v3.md
MARP        = npx --yes @marp-team/marp-cli@latest

# Genera l'HTML delle slide (standalone, apribile nel browser)
slides:
	$(MARP) $(SLIDES_SRC) -o $(basename $(SLIDES_SRC)).html
	@echo "\n[OK] Slide HTML generate: $(basename $(SLIDES_SRC)).html"

# Genera il PDF delle slide (utile come backup offline durante il talk)
slides-pdf:
	$(MARP) --pdf --allow-local-files $(SLIDES_SRC) -o $(basename $(SLIDES_SRC)).pdf
	@echo "\n[OK] Slide PDF generate: $(basename $(SLIDES_SRC)).pdf"

# Modalità watch + server locale con anteprima live (Ctrl+C per uscire)
slides-watch:
	$(MARP) --watch --server $(SLIDES_SRC)
