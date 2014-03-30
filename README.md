# CSV-LD processor for Ruby

[CSV-LD][] transforms CSV-formatted files, or open files that provide an equivalent interface to the [Ruby CSV library][] which yields each row as an array, or returns an array of arrays.

[CSV-LD][] uses a JSON-LD formatted template document called the _CSV-LD mapping frame_ (_mapping frame_ for short) as the specification for turning each row from the CSV into a [JSON-LD node]() by matching column headers from the CSV to _value patterns_ within the _mapping frame_, performing suitable transformations on the resulting values, depending on the location of the _value pattern_ within the _mapping frame_.

[Ruby CSV library]: http://ruby-doc.org/stdlib-2.1.0/libdoc/csv/rdoc/CSV.html
[CSV-LD]: https://www.w3.org/2013/csvw/wiki/CSV-LD