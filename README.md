# GoogleContactsApi

An unofficial Google Contacts API for ruby. Depend on [google api client(0.8.6)](https://github.com/google/google-api-ruby-client/tree/v0.8.6)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'google_contacts_api'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install google_contacts_api

## Usage

```ruby
user = GoogleContactsApi::User.new(access_token, refresh_token)

# contacts
user.contacts
user.group_contacts(group_id)
user.contact(contact_id)
user.update_contact(contact_id,
   {
     name: { familyName: last_name_value, givenName: first_name_value },
     phonetic_name: { familyName: last_name_value, givenName: first_name_value },
     email: { work: { address: email_address_value, primary: true}, other: {...} }, # default email types are work, home, other, but you could create any name you want.
     phone: { work: { address: email_address_value, primary: true}, other: {...} }, # default phone types are work, home, other, mobile, main, home_fax, work_fax, pager, google voice is grandcentral, but you could create any name you want.
     address: { work: { street: street, city: city, region: region, postcode: postcode, country: Taiwan}, other: {...}
     birthday: '1982-01-08,
     add_group_ids: [group_id, group_id], # or use group id array or only group_id,
     remove_group_ids: group_id
   }
)

# groups
user.groups
user.create_group(title)
user.group_base_url(group_id)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ilake/google_contacts_api. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.

## Credits
- [google-api-ruby-client with the Google Contacts API example](https://gist.github.com/cantino/d1a63045fbfe5fc55a94)
- [Class to interface with Google Contacts API in Ruby. Use api-ruby-client 0.9.x series](https://gist.github.com/lightman76/2357338dcca65fd390e2)
- [aliang/google_contacts_api](https://github.com/aliang/google_contacts_api/)

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

