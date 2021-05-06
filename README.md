# Emissions Tracker

Project completed as part of my internship at the Ministry for the Environment, where I recreated the currently live Emissions Tracker (see here https://emissionstracker.mfe.govt.nz/) within R Shiny.

Context regarding the background of the project and an overview on the development of the application can be found in 'Report'.

In order to run the app, simply need to open and run the 'app.R' file. All required packages will be loaded in automatically.

## A brief rundown of each of the R files
* app.R - contains all the Shiny App functionality (UI, Server, Reactivity etc.)

* helper.R - contains helper functions created to aid the manipulation of data for app.R.

* Emissions.R - file which was created to test different functions before implementing it in app.R (not required to run app.R).  

* library.R - file which downloads (if required) and imports all libraries needed to run the app.
  
## Overview of functionality for the App
* Click on any of the bars in the main Emissions plot to go into a deeper breakdown of said bar.
  * Return to the above layer by pressing the 'Go up' button, or return to the initial Sector layer by pressing 'Reset'
* Breakdown of Sectors is shown next to the 'Reset' button
* Change from graph view to tabular view by pressing the 'Table View' button (may switch between views whenever, and is compatible with different years and greenhouse gas filters).
* Click on any of the bars in the 'Year' to filter by that specific year.
* Click on any of the bars (one or many) in the 'Greenhouse Gas' plot to filter by that/those greenhouse gases.
  * Press 'Reset' to remove all filters.
* In the tabular view, can change the Year to compare by selecting a year from the drop down box or by changing the current year (as shown by Selected Year).
  * You are able to continue down any given sector by clicking on the 'Name on tab' in the Tabular view. 
* If pressing a Sector no longer does anything, you have reached the lowest level in the hierarchy.
