# Free Space Optical Communication Simulation for a LEO satellite constellation

This project implements a dynamic Free Space Optical (FSO) satellite constellation simulation in MATLAB using the Satellite Communications Toolbox. A multi-plane low Earth orbit constellation is generated with configurable orbital parameters including altitude, inclination, number of orbital planes, and satellites per plane. 

<img width="1154" height="882" alt="Simulation" src="https://github.com/user-attachments/assets/482f9e76-966a-435e-814e-106b84ad90cb" />

Two geographically separated ground stations are integrated into the scenario to represent communication endpoints. Each satellite is equipped with transmitters, receivers, gimbals, and Gaussian antenna models to emulate optical communication terminals. The simulation precomputes visibility access between all nodes in the network, including satellite-to-satellite and satellite-to-ground links. A graph-based routing strategy is then applied at every simulation timestep using a Breadth-First Search (BFS) algorithm to dynamically determine end-to-end communication paths between the ground stations. 

Network connectivity is evaluated over a 24-hour period, allowing automatic rerouting as orbital geometry changes. Finally, the program extracts and visualizes the time intervals during which complete end-to-end connectivity is maintained, providing a temporal analysis of network availability in the simulated FSO constellation. The result can be seen in the next image. As you may see, there are periods during the day where communication is lost between stations. LEO constellations like Starlink solve this problem by having around 8000 satellites (by the time I did this project) insted of the 40 we used. The amount of satellites in the simulation can be increased, but it will require more processing and time to simulate. 

<img width="1531" height="867" alt="SimResult" src="https://github.com/user-attachments/assets/e0e79b00-3082-49b1-9656-76d894630f63" />

This project was done as a part of a research for my Theory of Communications and Signal Processing class, where me and my group did research in Deep Space Optical Communication (DSOC) and innovative ways of communication. You can access a video of the beginning of the simulation in the provided link below. As it took around 5 minutes to complete the calculations needed to simulate, it was sped 10x.

https://youtu.be/tNuTMeUVMtw
