# Contributing to Video.jl

Thank you for your interest in contributing to Video.jl! This project is maintained by volunteers and we welcome contributions of all kinds, including new videos, bug fixes, features, and documentation improvements.

## Adding New Media

If you know of a Julia talk, tutorial, or presentation that isn't on the site, we would love to have it! Our data is managed via JSON files and a PostgreSQL database.

### Option 1: Submit an Issue
The easiest way to contribute media is to [open an issue](https://github.com/Video.jl/Video.jl/issues/new) on our GitHub repository. Please include:
- The video URL (YouTube, Vimeo, etc.)
- The title of the talk
- The speaker's name
- The event where the talk was given

### Option 2: Submit a Pull Request
If you are comfortable with Git:
1. Fork the Data Repository.
2. Create a new branch for your addition.
3. Add a new `.json` file for the video in the appropriate event folder. 
4. Ensure the JSON follows our schema (see existing files for examples).
5. Open a Pull Request!

## Developing the Site

Video.jl uses [Genie.jl](https://genieframework.com/) (Julia) for the backend API and standard HTML/CSS/Vanilla JS for the frontend.

### Prerequisites
- Julia (latest stable version)
- PostgreSQL (for the database, though SQLite may be supported depending on configuration)

### Running Locally
1. Clone the repository:
   ```bash
   git clone https://github.com/Video.jl/Video.jl.git
   cd Video.jl
   ```
2. Setup the environment and run the server:
   ```bash
   julia --project=. bin/server
   ```
3. Visit `http://localhost:8000` in your browser.

## Reporting Bugs
If you find a bug in the website layout, search functionality, or data inaccuracy, please [open an issue](https://github.com/Video.jl/Video.jl/issues/new) and describe the problem. Any screenshots or step-by-step instructions to reproduce the problem are highly appreciated.

## Community Guidelines
Please be respectful and patient. We are all volunteers doing this in our free time to benefit the Julia community.
