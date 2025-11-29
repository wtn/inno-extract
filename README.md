# Inno Extract

Ruby gem.

## Usage

```ruby
require "inno/extract"

installer = Inno::Extract::Installer.new("setup.exe")

installer.version        # => "6.3.0"
installer.manifest.files # => [{install_path: "app/foo.dll", file_hash: "abc123...", ...}, ...]

installer.extract_to("output/")
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wtn/inno-extract.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
