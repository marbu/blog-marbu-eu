site: site.hs
	ghc -threaded --make $^
	strip $@

clean:
	rm site site.o site.hi
