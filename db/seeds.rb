# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

Article.create(
  [
    { 
      title: "First Art",
      content: "Content OF FirsT ArtIcle.",
      published_on: Date.today
    }, 
    { 
      title: "second article",
      content: "Content OF SeconD ArtIcle",
      published_on: Date.today - 1
    },
    {
      title: "third ArticLE",
      content: "content of ThirD ArtIcle",
      published_on: Date.today - 2
    },
    {
      title: "Fourth ArticLE",
      content: "Content of FourTH ArtIcle",
      published_on: Date.today - 3
    },
    {
      title: "FifTH ArticLE",
      content: "Content of FIFtH ArtIcle",
      published_on: Date.today - 4
    },
    {
      title: "SixTH ArticLE",
      content: "contENt of SIXTH ArtIcle",
      published_on: Date.today - 5
    }
  ]
)