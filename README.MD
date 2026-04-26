# mcLaw

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Framework](https://img.shields.io/badge/framework-Qbox-green.svg)
![Dependency](https://img.shields.io/badge/dependency-ox__lib-red.svg)
![Completed](https://img.shields.io/badge/Completed-5%25-orange)
![Repo](https://img.shields.io/badge/github-mcLaw-blue?logo=github)

This is an end-to-end judicial management system designed for Qbox. It provides a complete legal infrastructure for your server, allowing legal professionals to manage the entire litigation process—from opening investigation files and sending official subpoenas to conducting court hearings and managing prison sentencing.

## Features

- Case Management: Create and track comprehensive lawsuits with detailed status updates.
- Investigation Files: Build criminal cases by attaching evidence, suspect profiles, and witness statements.
- Subpoena System: Send official legal notifications and summons directly to players.
- Court Room Tools: Integrated tools for judges to manage hearings, deliberate, and issue final verdicts.
- Sentencing and Imprisonment: Automated system for processing jail time and fines directly through the judicial interface.
- Qbox Native: Fully optimized for the Qbox Project ecosystem, utilizing modern group and permission systems.
- OxLib Integration: High-quality UI elements including context menus, input dialogs, and progress bars.
- Persistence: All legal records, files, and warrants are securely stored via oxmysql.
- Performance: Highly optimized code ensuring 0.00ms idle resmon.

## Dependencies

Ensure you have the following resources installed:

- [Qbox Core](https://github.com/Qbox-Project/qbx_core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)

## Installation

1. Download the resource and place it in your resources folder.
2. Rename the folder **mcLaw-main** to **mcLaw** (ensure no brackets).
3. Import the provided install.sql file into your database (if applicable).
4. Add the following line to your server.cfg:
   ```cfg
   ensure mcLaw

## Support

- Discord: *mcdikmen*

- Issues: Create a ticket on the GitHub Issues page.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

© 2026 Mcdikmen. All rights reserved.