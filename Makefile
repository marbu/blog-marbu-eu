.PHONY: clean

site: site.hs
	ghc -dynamic -threaded --make $^
	strip $@
	./site clean

clean:
	rm site site.o site.hi
