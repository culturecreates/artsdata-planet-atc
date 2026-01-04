ATC Extract-Load-Transform into Artsdata
========================

Related Documents:
1. collaboration on [ATC-Artsdata Mapping](https://docs.google.com/document/d/1eTiR_we7RJhxakn-v8R8k5I9npn24yDMfjYiVFeSo6Q/edit?tab=t.0) for calling Artsdata APIs ([backup](https://docs.google.com/document/d/19YNY_mQ0lgWKHCJ1C_2txPElG8IZj3Y2kBJw1FzAjbg/edit?tab=t.0)).

2. [Display of Identifiers in the ATC User Interface](https://docs.google.com/document/d/1-TTK2qHw30u5cG3j9auktZwxJwmhBfJpfgyKPe8FWIQ/edit?tab=t.0#heading=h.flrpszbkqa31)
3. [ATC UAT - Ross Paton](https://docs.google.com/document/d/1fEE-b1Jv37NIhKG5B_oS4pH4UpIHfA-22blRun4SryQ/edit?tab=t.0#heading=h.tahucxxalii3) on the user accesptance testing

ATC Iteration 2
================
Using the ATC APIs and the mapping developed in this doc https://docs.google.com/document/d/1gMpPgQaVxZxssyaiub1azj1n8QnfSyJyNRNV7z5t3Mg/edit?tab=t.0

reference: https://docs.google.com/spreadsheets/d/1BsO2tA_DCy9q4OBsaJmWr4wAi7aWiPucofBQ3GTIgMY/edit?usp=sharing


Manual Publish
==============
To manually publish ATC data to the Artsdata Databus, navigate to the actions tab and run workflow "[Fetch and Push ATC entities](https://github.com/culturecreates/artsdata-planet-atc/actions/workflows/main.yml)"



Local Development
================

To call the ATC API locally and downoad the JSON data:
1. git clone repo
2. install ruby 
3. `bundle install`
4. `rake`
5. `ruby src/fetch_atc_antities.rb`

Note: You will need the ATC authorization token

To convert JSON to RDF:
1. Run Docker
2. `./run_ontorefine.sh`

To publish data to the databus:
1. Run the workflow 