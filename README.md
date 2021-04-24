# tools

This repo should be checked out before any other repo prior to doing any work on 
any project groupings. This repo has environment specific setups and scripts that
make your work easier.

Checkout this repo:
```bash
git clone git@github.com:fortytwobinary/tools.git
cd tools
source grouprc
cd ..
```
We navigated back our projects directory. Now run setup.sh to clone the set of 
repos we want. Hint: `setup.sh --help`

```bash
setup.sh --devops
```
This command clones all the repos in the project directory that are related to
my fortytwobinary lab work.
