build:
	cp www/static/* www/_site; \
	cd core; zig build; \
	cd ../www; \
	npm run build; \
	rm _site/core.wasm; \
	cp ../core/zig-out/bin/core.wasm _site/;

run:
	cd www/_site; \
	python3 -m http.server;
