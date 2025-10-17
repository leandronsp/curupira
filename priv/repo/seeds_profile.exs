# Script to populate blog profile with initial data
# Run with: mix run priv/repo/seeds_profile.exs

alias Curupira.Repo
alias Curupira.Blog.Profile

# Delete existing profile if any
Repo.delete_all(Profile)

# Create profile with data
%Profile{}
|> Profile.changeset(%{
  name: "Leandro Proença",
  bio: "Backend engineer with 15+ years building software for startups and enterprises worldwide. Language junkie specializing in Ruby, Elixir, Rust, and occasionally diving into Assembly and low-level programming.

I write about systems programming, backend architecture, concurrency patterns, and cloud infrastructure. You'll find deep dives into how computers actually work under the hood, building production-grade APIs, performance optimization, and everything DevOps.

I believe in understanding fundamentals before reaching for abstractions. Most articles include practical examples and hands-on code you can run yourself."
})
|> Repo.insert!()

IO.puts("✓ Blog profile populated successfully!")
