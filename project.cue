// project cuefile for Dagger CI and other development tooling related to this project.
package main

import (
	"dagger.io/dagger"
	"universe.dagger.io/docker"
	"universe.dagger.io/bash"
)

// python build for linting, testing, building, etc.
#PythonBuild: {
	// client filesystem
	filesystem: dagger.#FS

	// python version to use for build
	python_ver: string | *"3.9"

	// poetry version to use for build
	poetry_ver: string | *"1.2.0"

	// container image
	output: _python_build.output

	// referential build for base python image
	_python_pre_build: docker.#Build & {
		steps: [
			docker.#Pull & {
				source: "python:" + python_ver
			},
			docker.#Run & {
				command: {
					name: "mkdir"
					args: ["/workdir"]
				}
			},
			docker.#Set & {
				config: {
					workdir: "/workdir"
					env: {
						POETRY_VIRTUALENVS_CREATE: "false"
						PRE_COMMIT_HOME:           "/workdir/.cache/pre-commit"
					}
				}
			},
			docker.#Copy & {
				contents: filesystem
				source:   "./pyproject.toml"
				dest:     "/workdir/pyproject.toml"
			},
			docker.#Copy & {
				contents: filesystem
				source:   "./poetry.lock"
				dest:     "/workdir/poetry.lock"
			},
			docker.#Copy & {
				contents: filesystem
				source:   "./.pre-commit-config.yaml"
				dest:     "/workdir/.pre-commit-config.yaml"
			},
			docker.#Run & {
				command: {
					name: "pip"
					args: ["install", "--no-cache-dir", "poetry==" + poetry_ver]
				}
			},
			docker.#Run & {
				command: {
					name: "poetry"
					args: ["install", "--no-root", "--no-interaction", "--no-ansi"]
				}
			},
			// init for pre-commit install
			docker.#Run & {
				command: {
					name: "git"
					args: ["init"]
				}
			},
			docker.#Run & {
				command: {
					name: "poetry"
					args: ["run", "pre-commit", "install-hooks"]
				}
			},
		]
	}
	// python build with likely changes
	_python_build: docker.#Build & {
		steps: [
			docker.#Copy & {
				input:    _python_pre_build.output
				contents: filesystem
				source:   "./"
				dest:     "/workdir"
			},
		]
	}
}

// Convenience cuelang build for formatting, etc.
#CueBuild: {
	// client filesystem
	filesystem: dagger.#FS

	// output from the build
	output: _cue_build.output

	// cuelang pre-build
	_cue_pre_build: docker.#Build & {
		steps: [
			docker.#Pull & {
				source: "golang:latest"
			},
			docker.#Run & {
				command: {
					name: "mkdir"
					args: ["/workdir"]
				}
			},
			docker.#Run & {
				command: {
					name: "go"
					args: ["install", "cuelang.org/go/cmd/cue@latest"]
				}
			},
		]
	}
	// cue build for actions in this plan
	_cue_build: docker.#Build & {
		steps: [
			docker.#Copy & {
				input:    _cue_pre_build.output
				contents: filesystem
				source:   "./project.cue"
				dest:     "/workdir/project.cue"
			},
		]
	}

}

#ValeBuild: {
	// client filesystem
	filesystem: dagger.#FS

	// output from the build
	output:      _vale_build.output
	_vale_build: docker.#Build & {
		steps: [
			docker.#Pull & {
				source: "jdkato/vale:latest"
			},
			docker.#Run & {
				entrypoint: ["apk"]
				command: {
					name: "update"
				}
			},
			docker.#Run & {
				entrypoint: ["apk"]
				command: {
					name: "upgrade"
				}
			},
			docker.#Run & {
				entrypoint: ["apk"]
				command: {
					name: "add"
					args: ["bash"]
				}
			},
			docker.#Copy & {
				contents: filesystem
				source:   "./.vale.ini"
				dest:     "/vale.ini"
			},
			docker.#Copy & {
				contents: filesystem
				source:   "./README.md"
				dest:     "/docs/README.md"
			},
			docker.#Copy & {
				contents: filesystem
				source:   "./research_steps"
				dest:     "/docs/research_steps"
			},
			docker.#Run & {
				command: {
					name: "sync"
				}
			},
			docker.#Set & {
				config: {
					workdir: "/docs"
				}
			},

		]
	}
}

#TextLintBuild: {
	// client filesystem
	filesystem: dagger.#FS

	// output from the build
	output:          _textlint_build.output
	_textlint_build: docker.#Build & {
		steps: [
			docker.#Pull & {
				source: "node:latest"
			},
			docker.#Run & {
				command: {
					name: "mkdir"
					args: ["/workdir"]
				}
			},
			docker.#Set & {
				config: {
					workdir: "/workdir"
				}
			},
			docker.#Copy & {
				contents: filesystem
				source:   "./package.json"
				dest:     "/workdir/package.json"
			},
			docker.#Copy & {
				contents: filesystem
				source:   "./package-lock.json"
				dest:     "/workdir/package-lock.json"
			},
			docker.#Run & {
				command: {
					name: "npm"
					args: ["install"]}
			},
			docker.#Copy & {
				contents: filesystem
				source:   "./"
				dest:     "/workdir"
				exclude: ["./node_modules"]
			},
		]
	}
}

dagger.#Plan & {

	client: {
		filesystem: {
			"./": read: contents:             dagger.#FS
			"./project.cue": write: contents: actions.clean.cue.export.files."/workdir/project.cue"
		}
	}
	python_version: string | *"3.9"
	poetry_version: string | *"1.2.0"

	actions: {

		_python_build: #PythonBuild & {
			filesystem: client.filesystem."./".read.contents
			python_ver: python_version
			poetry_ver: poetry_version
		}

		_cue_build: #CueBuild & {
			filesystem: client.filesystem."./".read.contents
		}

		_vale_build: #ValeBuild & {
			filesystem: client.filesystem."./".read.contents
		}

		_textlint_build: #TextLintBuild & {
			filesystem: client.filesystem."./".read.contents
		}

		// applied code and/or file formatting
		clean: {
			// code formatting for cuelang
			cue: docker.#Run & {
				input:   _cue_build.output
				workdir: "/workdir"
				command: {
					name: "cue"
					args: ["fmt", "/workdir/project.cue"]
				}
				export: {
					files: "/workdir/project.cue": _
				}
			}
		}

		// forced non-zero return to show vale warnings and suggestions 
		vale_nonzero: bash.#Run & {
			input: _vale_build.output
			script: contents: """
					/bin/vale . && false
				"""
		}

		// linting to check for formatting and best practices
		lint: {
			pre_commit: docker.#Run & {
				input:   _python_build.output
				workdir: "/workdir"
				command: {
					name: "poetry"
					args: ["run", "pre-commit", "run", "--all-files"]
				}
			}
			vale: docker.#Run & {
				input: _vale_build.output
				entrypoint: ["/bin/vale"]
				command: {
					name: "."
				}
			}
			textlint: docker.#Run & {
				input: _textlint_build.output
				command: {
					name: "npx"
					args: ["textlint", "/workdir/**/*.md"]
				}
			}
		}
	}
}
