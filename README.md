# runkeeper_import

This is a script I build to automate importing a lot of gpx files at once. 
The script mimics a user login to https://runkeeper.com and calls endpoints
necessary for uploading a GPX file.

Usage

Install required gems
```
cd runkeeper_import/
bundle install
```

Start a pry session
```
bundle exec pry -r ./importer.rb
```

Create new Importer object, run import
```
importer = importer = Importer.new(gpx_zip_file: '<gpx_zip_file>.zip', username: '<username>', password: '<password>')
importer.import
```

After running the import, assuming everything worked you can get a list of 
created activity ids in the @gpx_hashes instance variable
```
created_ids = importer.gpx_hashes.map { |hash| hash[:activity_id] }
```

