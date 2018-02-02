using Documenter, FWF
 
makedocs(modules=[FWF],
        doctest=true)
 
deploydocs(deps   = Deps.pip("mkdocs", "python-markdown-math"),
    repo = "github.com/GITHUBNAME/GITHUBREPO.git",
    julia  = ".6",
    osname = "linux")