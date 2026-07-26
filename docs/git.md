# git

## clone

Clone each repository independently and use its tracked branch:

```sh
git clone https://github.com/DevAbdoTolba/UnivAI
git clone https://github.com/abdalrahmanalirajab/UnivAI-app
git clone --branch temp https://github.com/AhmeedFatehy/UnivAI-Agent
git clone https://github.com/muhameedhanyyy/UnivAI-live
git clone https://github.com/AhmedSamirKhalaf/UnivAI-exam_system
```

## update

Run this inside each repository:

```sh
git pull --ff-only
```

Tracked branches: `UnivAI-Agent` uses `temp`; every other repository uses
`main`.

Core does not initialise or update the other repositories. Each repository
builds, tests, and ships independently.
