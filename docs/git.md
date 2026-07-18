# git

## first time

```sh
git clone --recurse-submodules https://github.com/DevAbdoTolba/UnivAI
```

forgot the flag?

```sh
git submodule update --init --recursive
```

## update

```sh
git pull
git submodule update --init --recursive
```

## a submodule got new commits

```sh
git submodule update --remote UnivAI-Agent
git add UnivAI-Agent
git commit -m "bump UnivAI-Agent"
git push
```

everyone else: see **update**.

## work inside a submodule

```sh
cd UnivAI-Agent
git checkout temp        # submodules land detached — pick the branch first
# ...commit, push as normal...
cd ..
git add UnivAI-Agent && git commit -m "bump UnivAI-Agent" && git push
```

branches: `UnivAI-Agent` → `temp`, everything else → `main`.
