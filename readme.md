# Math Practice

I made this program to generate practice sheets for my kids. It takes a YAML configuration file and produces a pdf with the configured problem sets.

See `example/` for an example configuration and PDF output.

I was using https://webmathminute.com which is great, but I wanted a few more things:

- Print a week's worth of practice sheets at a time, with different settings for each day's sheet
- Create sheets with different parameters for different operations (eg, hard addition, medium subtraction, easy multiplication and division)
- Preserve settings from use to use, rather than re-entering them each time
- Print an answer key for the week

### Usage

```
ruby app.rb path/to/math.yml
# Creating practice sheets from example/exercises.yml
# Created example/worksheets.pdf
```

### Tests

```
ruby test.rb
```
