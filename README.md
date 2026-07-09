# ADUsersSearch
Powershell compiled executable gui for listing AD users by specific fields.

- Windows executable tool for listing AD users by by specific fields (especially usable for phone search an others).  
(compiled from Powershell with ps2exe module, using just one file, containing the code - ADUsersSearchAll.ps1)
<!-- two spaces  for rodinary newline (after 'users') -->

- The powershell source is in the code. It can be runned too - by ADUsersSearchStart.ps1

- For seeng all details, executing the exe or ps1 must be done by user with appropriate rights on AD.

- Running with ordinary user gives limted results, see the configuration file - ADUsersSearchConf.xml

- It doesn't need installed RSAT (This was in former versions). Uses .NET Directory Services directly.

- AI assisted for some topics

- The interface is intuitive
