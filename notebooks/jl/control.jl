### A Pluto.jl notebook ###
# v0.19.9

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ cc5fa8b8-4da3-11ee-28fd-7dacab544db3
begin
	using DifferentialEquations
	using Plots
	using Plots.PlotMeasures
	using PlutoUI
	using SymPy
	import PlutoUI:combine

	#https://mdpetters.github.io/cee200/assets/
	cs_url = "https://mdpetters.github.io/cee200/assets/cold_stage.png"
	tec_url = "https://mdpetters.github.io/cee200/assets/tec_performance.png"
	control1_url = "https://mdpetters.github.io/cee200/assets/control1.svg"
	control2_url = "https://mdpetters.github.io/cee200/assets/control2.svg"
	control3_url = "https://mdpetters.github.io/cee200/assets/control3.svg"
	control4_url = "https://mdpetters.github.io/cee200/assets/control4.svg"
	control5_url = "https://mdpetters.github.io/cee200/assets/TC-36-25_RS232_02.jpg"

	md"""
	$(TableOfContents(depth=4))
	#  Control Systems
	"""
end

# ╔═╡ aabae4cb-3912-408d-bacf-267f2440c047
Markdown.MD(
	Markdown.Admonition("warning", "Key Concept", [md"
A control system consists of components and circuits that work together to maintain the process at a desired operating point. Every home or an industrial plant has a temperature control that maintains the temperature at the thermostat setting. In industry, a control system may be used to regulate some aspect of production of parts or to maintain the speed of a motor at a desired level.
"]))

# ╔═╡ 9db0e27f-32f5-4b03-9d70-5dea9f079ecb
md"""
# Thermolectric Cold-Stage

## Introduction
This module will develop the design and analysis of simple control systems using a simple example application: an enclolsed thermoelectrically cooled/heated plate surface whose temperature can be varied between −45 °C and +90 °C.  

$(Resource(cs_url, :width => 2500px))

**Figure.** A  thermoelectric cold plate with an enclousre cell. 1: heat sink, 2: barb connectors, 3: TEC module, 4: base block, 5: cold plate, 6: spacers, 7: M2.5 screw, 8: M4 screw, 9: glass lid, T: thermistor opening. Two thermistor openings are located on the left front facing side of the baseblock. (Source: Mahant et al., 2023).

The purpose of the heat sink is the maintain one side of the TEC module at a constant temperature. 

## Instrument Model

```math
\frac{dT}{dt} = k(T_{env}-T) - \frac{Q(V,\Delta T)}{mc}
```

where ``k`` is the coefficient of heat transfer, ``T_{env}`` is the temperature of the environment, ``T`` is the temperature of the place, ``Q`` is the heat transfer across the TEC, ``m`` is the mass of the metal stage, and ``c`` is the heat capacity of the metal. Recall from a previous homework assignment that the performance of the TEC can be modeled via the model

```math
Q(V,\Delta T) = a_1\sqrt{V} + a_2\Delta T + a_3 
```

where  ``V`` is the voltage applied to the TEC module, ``\Delta T`` is the temperature difference between the hot and cold side, and ``a_i`` are fitted coefficients that determine the performance for a specific TEC model.  

$(Resource(tec_url, :height => 900px))

"""

# ╔═╡ ba749db8-c015-4137-ac7e-92fc0bfbe7ce
Markdown.MD(
	Markdown.Admonition("info", "Exercise", [md"
Based on the performance characteristic of the TEC module. Predict the coldest temperature that the stage can reach assuming that the heat sink temperature is 280K. 
	"]))

# ╔═╡ a25d1d5d-abc8-4ec4-80b2-ecdaea755a1c
md"""
## State Space Representation

The instrument performance can also be described by the canonical state-space model equations

```math
\begin{eqnarray}
 & \quad \vec{q}'(t) &= \mathbf{A}\vec{q}(t) + \mathbf{B} \vec{f}(t) \\
 & \quad \vec{y}(t) &=  \mathbf{C}\vec{q}(t) + \mathbf{D} \vec{f}(t) \\
\end{eqnarray}
```

where ``\vec{q} = [T]``, ``\quad \vec{y} = [T]``, and  ``\quad\vec{f} = 
\begin{bmatrix}
\sqrt{V} & T_{hot} & 1 & T_{env}
\end{bmatrix}
``

And the coefficients:

``\quad A = [k + \frac{a_2}{mc}]``,  ``\quad B = \begin{bmatrix} -\frac{a_1}{mc} \\ -\frac{a_2}{mc} \\ -\frac{a_3}{mc} \\ k \end{bmatrix}``, ``\quad C = [1]``, and ``D = \begin{bmatrix} 0 \\ 0 \\ 0 \\ 0 \end{bmatrix}``

Thus we can use our generic state space solver. 
"""

# ╔═╡ be1a604c-6cf6-405f-9fa0-86e3b454315e
function state_space_solver(A, B, C, D, q0, f, tspan)
	h(q, p, t) = A*q + B*f(t)  # canonical equation 1
	y(q, t) = C*q + D*f(t)     # canonical equation 2
	
	problem = ODEProblem(h, q0, tspan, Float64[]) 
	solution = solve(problem, RK4(), reltol = 1e-12, abstol = 1e-12)
	return map(y, solution.u, solution.t), solution.t
end

# ╔═╡ 759f6f53-866c-4cc8-9bb5-41be3b43f1dc
md"""
## Solution for Constant V

The function below intializes the problem with known coefficients for a constant input voltage V. The stage cools and reaches an equilibrium temperature that is controlled by the heat sink temperature and the heat loss rate to the environment. 
"""

# ╔═╡ bdc5a009-c6c4-434d-a619-63081c6af32d
function solve_const_v(V)
	m = 0.3                          # kg
	c = 502.0                        # J kg-1 K-1
	k = 300.0*(0.025*0.025)/(m*c)    # s^-1
	a1 =  11.07 				     # W V^-0.5 
	a2 =  -0.352                     # W K^-1
	a3 =  -8.29                      # W

	u0 = [300.0]
	tspan  = [0.0, 3000.0]                   # 0 to 1000 s
	f(t) = [sqrt(V), 280.0, 1.0, 300.0] # V = 5V, Th = 280K, 1, Tenv = 300K
	
	A = -k + a2/(m*c)
	B = [-a1/(m*c) -a2/(m*c) -a3/(m*c) k]
	C = 1.0
	D = [0.0 0.0 0.0 0.0]
	
	state_space_solver(A, B, C, D, u0, f, tspan)	
end

# ╔═╡ b8fe4424-9eac-4011-85ba-f1bf5e72c718
Markdown.MD(
	Markdown.Admonition("info", "Exercise", [md"
- Compare the model solution against your earlier prediction. 
- Does the equilibration time depend on the voltage?
- Using the same equipment, could you imaging a faster path to cool to the equilibrium temperature?
	"]))

# ╔═╡ 1b1dbf06-c67b-4447-9049-4ab1bf82ee8a
@bind myV combine() do Child
	md"""
	Voltage:  $(
		Child(Slider(0:1:12, default = 6, show_value = true))
	) 
	"""
end

# ╔═╡ f4c5f8dd-a66f-4b1a-8a6f-3e4ad9615999
outvec = solve_const_v(myV[1])

# ╔═╡ cf63fd31-4c00-46e5-8648-713b59080eba
begin
	pos3 = map(x -> x[1], outvec[1])
	ts3 = outvec[2]
	plot(ts3/60.0, pos3, color = :black, label = "RK4 Solution", lw = 1, 
		xlabel = "Time (min)", ylabel = "T (K)", size = (700, 300), bottom_margin = 20px, left_margin = 10px, minorgrid = :true, framestyle = :box)
end

# ╔═╡ 451a1910-4ce9-4e15-bca3-c516e20e5bd5
md"""
## Solution for Time Varying V

The function below intializes the problem with known coefficients for a time-varying input voltage V. Unsurprisingly, the changing voltage is mirrored in the changing temperature around some average temperature.
"""

# ╔═╡ c42f51a3-a02d-4c86-beee-7feedd378ad0
function solve_variable_v(fv)
	m = 0.3                          # kg
	c = 502.0                        # J kg-1 K-1
	k = 300.0*(0.025*0.025)/(m*c)    # s^-1
	a1 =  11.07 				     # W V^-0.5 
	a2 =  -0.352                     # W K^-1
	a3 =  -8.29                      # W

	
	u0 = [300.0]
	tspan  = [0.0, 3000.0]                   # 0 to 1000 s
	f(t) = [fv(t), 280.0, 1.0, 300.0]    
	
	A = -k + a2/(m*c)
	B = [-a1/(m*c) -a2/(m*c) -a3/(m*c) k]
	C = 1.0
	D = [0.0 0.0 0.0 0.0]
	
	state_space_solver(A, B, C, D, u0, f, tspan)	
end

# ╔═╡ 538e7d53-5cc3-4447-b1c7-3d02a0946f09
begin
	fex(t) = (sin(0.01*t) + 1.0)/2.0*sqrt(3) + 1
	outvec1 = solve_variable_v(fex)
	ts4 = outvec1[2]
	p1 = plot(ts4./60, fex.(ts4), color = :black, label = :none,
		ylabel = "V")
	pos4 = map(x -> x[1], outvec1[1])
	
	p2 = plot(ts4/60.0, pos4, color = :black, label = "RK4 Solution", 
		lw = 1, xlabel = "Time (min)", ylabel = "T (K)")
	plot(p1, p2, layout = grid(2,1))
end

# ╔═╡ 6369c1ac-e52c-4d81-869d-77cbd483fd8b
md"""
## Block Diagram Representation

Block diagrams consist of a single block or a combination of blocks. These are used to represent the control systems in pictorial form.

Recall the state-space equations:

```math
\begin{eqnarray}
 & \quad \vec{q}'(t) &= \mathbf{A}\vec{q}(t) + \mathbf{B} \vec{f}(t) \\
 & \quad \vec{y}(t) &=  \mathbf{C}\vec{q}(t) + \mathbf{D} \vec{f}(t) \\
\end{eqnarray}
```

We have the input vector ``\vec{f}``, the output vector ``\vec{y}``. The system is subject to initial conditions ``\vec{q_0}``. The `process` box solves for the evolution of the system over time ``t``.

$(Resource(control1_url, :width => 1500px))

For the cold stage, the inputs are ``\quad\vec{f} = 
\begin{bmatrix}
\sqrt{V} & T_{hot} & 1 & T_{env}
\end{bmatrix}
``, the process state variables are ``\vec{q} = [T]``, and the outputs are ``\quad \vec{y} = [T]``. Therefore the intial input ``\vec{q}_0`` is the intial temperature of the stage ``T_0``.
"""

# ╔═╡ 03a0fc10-9875-4248-8711-8a3887db30a5
md"""
# Discrete Event System Simulation

## Introduction
A discrete-event simulation (DES) models the operation of a system as a (discrete) sequence of events in time. Each event occurs at a particular instant in time and marks a change of state in the system. Between events, the system is allowed to evolve according to some set of rules. Here we simulate the system as a data acquisition system would perceive it. At each update event (determined by the sampling frequency), the data acquisition system reads the state using sensors, here the temperature of the cold stage, and perhaps other states such as the environmental temperature or the heat sink temperature. A typical data acquisition system would then write the data to file. The user may also change inputs to the system, for example the voltage supplied to the TEC module. 

## Block Diagram

Instead of solving for the evolution over the entire time domain, the discrete simulation soves for the evolution from time ``t \rightarrow t + \Delta t``.

$(Resource(control2_url, :width => 1500px))

To simulate the evolution of the system over longer times, the output of ``\vec{y}(t + \Delta t)`` is used to re-initialize the system. For the cold stage, the output is ``T`` and maps directly to the initial condition ``T_0``. This introduces: 

- External Observer: Every ``\Delta t`` we observe the state of the system.
- External Controller: Every ``\Delta t`` we can, in principle, update the system forcing vector ``\vec{f}``. 

"""

# ╔═╡ 8aa24500-d236-4e24-bf06-4db94e612a50
md"""

## Implementation

### ODE Solution 
The `update_system` function incrementally solves the differential equation in `dt` intervals, where `dt` is the time step. 
"""


# ╔═╡ 54a7e106-4537-4857-a9e7-fdc3e9bf4ba1
function update_system(T, V, dt; Thot = 280.0, Tenv = 300.0)
	m = 0.3                          # kg
	c = 502.0                        # J kg-1 K-1
	k = 200.0*(0.025*0.025)/(m*c)    # s^-1
	a1 =  11.07 				     # W V^-0.5 
	a2 =  -0.352                     # W K^-1
	a3 =  -8.29                      # W

	u0 = [T]
	tspan  = [0.0, dt]               # 0 to 1 s
	sig = sign(V)                    # Needed for negative V
	f(t) = [sig.*sqrt(abs(V)), Thot, 1.0, Tenv]    
	
	A = -k + a2/(m*c)
	B = [-a1/(m*c) -a2/(m*c) -a3/(m*c) k]
	C = 1.0
	D = [0.0 0.0 0.0 0.0]
	
	out = state_space_solver(A, B, C, D, u0, f, tspan)
	return out[1][end][]
end

# ╔═╡ f0ecf625-53f3-4595-8764-ab0a95c5b6e3
# example: new temperature for -3V after 1 second
update_system(300.0, -3.0, 1.0)

# ╔═╡ 17c3d4a5-048a-44c1-a5f0-5278a2322f60
md"""

### Simulation 
We can then perform a simulation where we step in 1s increments for n seconds. After each 1s increment, the temperature is updated. Note that `update_system` still used the ODE integration under the hood which may be at a higher time resolution. The trick here is that we observe the system every second and have the opportunity to intervene, for example by changing the voltage. Without intervention, the result should be the same as running the ODE solver for the same time interval. 

Note that the simulation is generic. It calls a black box "update_system", that can be replaced with any system imaginable.
"""

# ╔═╡ 25b351fa-69e6-482e-9543-12e1dde9e438
function simulation(T, V, n; dt = 1.0)
	ts = Float64[]
	Ts = Float64[]
	Vs = Float64[]
	push!(Ts, T)
	push!(Vs, V)
	push!(ts, 0.0)
	for i = 1:n
		theT = Ts[end]
		theV = Vs[end]
		newT = update_system(theT, theV, dt)
		push!(Ts, newT)
		push!(Vs, theV)
		push!(ts, ts[end] + dt)
	end

	return ts, Ts, Vs
end

# ╔═╡ 1163c920-d2ca-42e7-9b9e-1e19d494bb46
# Example simulation
ts, Ts, Vs = simulation(300.0, 2.0, 360; dt = 10)

# ╔═╡ 43c38357-4d59-457d-9b90-94ae1f267212
plot(ts./60, Ts, color = :black, label = "0.1 Hz Discrete Event Simulation", 
		xlabel = "Time (min)", ylabel = "T (K)", size = (700, 300), bottom_margin = 20px, left_margin = 10px, minorgrid = :true, framestyle = :box)

# ╔═╡ 7d030c04-ac3b-4832-a3e8-6053fc9c14e7
md"""

# Controlling the Temperature

## Controller Block Diagram

$(Resource(control3_url, :width => 2800px))

A controller can be used to control the signal. The setpoint of the controller is ``r``. The output of the process is subtracted from the setpoint to produce the error ``e(t)``. The error function is then passed into the controller, which outputs the input ``f(t)`` for the process to be controlled. The output of the controller is also sometimes referred to as the *manipulated variable*.

In the subsequent section we will focus on single-input and single-output (SISO) systems. Such systems a single-variable control system with one input and one output. Hence the vector notation for ``f(t)`` and ``y(t)`` has been dropped for simplicity. Further note that when employing for the discrete event simulation approach, the process initial condition is updated each time step. In a real-world system this step is of course implicit. For this reason, the initial condition arrow is marked as a dashed line. The controller has a few import properties. It has 

- knowledge about the *current error*
- knowledge about the *past error* 
- **no knowledge** about the process or *future error*
"""

# ╔═╡ 1ae8b353-df38-430f-b220-401adddac1d1
md"""
## On-Off Controller 
### Description
On-Off control is the simplest form of feedback control. An on-off controller simply drives the manipulated variable from fully closed to fully open depending on the position of the controlled variable relative to the setpoint. A common example of on-off control is the temperature control in a domestic heating system. When the temperature is below the thermostat setpoint the heating system is switched on and when the temperature is above the setpoint the heating switches off.

Unfortunately, if the heating switches on and off the instant the measured temperature crossed the setpoint then the system would chatter – repeatedly switch on and off at very high frequency. This, in turn would substantially reduce the lifetime of the unit. To avoid chattering, practical on-off controllers usually have a deadband around the setpoint. When the measured value lies within this dead-band the controller does nothing. Only when the value moves outside the deadband, the controller switches. The effect of this is to introduce continuous oscillation in the value of the controlled variable – the large the dead-band the higher the amplitude and lower the frequency.

### Implementation

An example implementation of the on-off controller is as follows. 

```math
e(t) = r-y(t)
```
```math
f(t) = 
\begin{cases}
 +1  & (e(t)-d) < 0 \land (e(t-\Delta t) - d) > 0 \\ 
 -1 & (e(t)+d) > 0 \land (e(t-\Delta t) + d) < 0
\end{cases}
```

where ``d`` is the deadband value. The output is either ``-1`` (full cooling) or ``+1`` full heating. These values may need to scaled by the output range of the input control, for the TEC to ``\pm 12V``.

For example, if the current output ``y = 15``, the setpoint ``r = 10`` we need to reduce ``y`` and keep the process outut at full cooling. Only when the ``y < 9``, i.e. outside the deadband the signal needs to shift to warming. However, we also only want to switch if we crossed the critical line, hence we need to reach into the past and make sure that the condition changed. The same logic is applied on the other end. We need to heat until we cross the ``y = 11`` before switching back. The function below implements an off control in the context of the simulation. 
"""

# ╔═╡ f85d4b96-e5d8-4d5c-aaed-df30c8c06084
function simulation_onoff(Tenv, n; Tset = 280.0, Tdead = 2.0, Thot = 280.0)
	dt = 1.0 
	# Need to know if we need heat or cool initially
	Vstart = (Tset < Tenv) ? 12.0 : -12.0
	ts = Float64[]  # Memory array for t
	Ts = Float64[]  # Memory array for T
	Vs = Float64[]  # Memory array for V
	
	push!(Ts, Tenv)    # Need to initialize two values for the control loop to work
	push!(Ts, Tenv)    # Need to initialize two values for the control loop to work
	
	push!(Vs, Vstart)
	push!(Vs, Vstart)
	
	push!(ts, 0.0)
	push!(ts, 1.0)

	# Control loop
	for i = 1:n-1
		theT = Ts[end]
		theV = Vs[end]

		et = Tset - Ts[end]     # current error
		etp = Tset - Ts[end-1]  # previous error

		if (et + Tdead) < 0 && (etp + Tdead) > 0
			theV = +12.0 # + 1 is scaled to + 12 V
		end
		
		if (et - Tdead) > 0 && (etp - Tdead) < 0
			theV = -12.0 # - 1 is scaled to + 12 V
		end
		
		newT = update_system(theT, theV, dt; Thot = Thot, Tenv = Tenv)
		push!(Ts, newT)
		push!(Vs, theV)
		push!(ts, ts[end] + dt)
	end

	return ts, Ts, Vs
end

# ╔═╡ 0c6f2477-1252-4485-9596-2748a2508e14
@bind on_off combine() do Child
	md"""
	``T_{set}\;(K)`` $(
		Child(Slider(200:10:400, default = 250, show_value = true))
	) ``T_{env}\;(K)`` $(
		Child(Slider(280:10:320, default = 300, show_value = true))
	) 
	
	``T_{hot}\; (K)`` $(
		Child(Slider(260:10:320, default = 280, show_value = true))
	)  ``T_{dead}\; (K)`` $( 
		Child(Slider(0:0.1:4, default = 2, show_value = true))
	)
	"""
end

# ╔═╡ 77c08e89-b5ca-45d3-8916-3ac8cf9453cb
let 
	Tset = on_off[1]
	Tenv = on_off[2]
	Thot = on_off[3]
	Tdead = on_off[4]
	ts, Ts, Vs = simulation_onoff(Tenv, 1000; Tset = Tset, Thot = Thot, Tdead = Tdead)
	p1 = plot(ts./60.0, Vs, label = :none, color = :black, ylabel = "V")
	p2 = plot(ts./60.0, Ts, color = :black, ylabel = "T (K)", label = "T system")
	plot!([0, ts[end]./60.0], [Tset, Tset], label = "T set", color = :darkred)
	plot!([0, ts[end]./60.0], [Tset-Tdead, Tset-Tdead], l = :dash, label = "±T dead", 
		color = :darkred)
	plot!([0, ts[end]./60.0], [Tset+Tdead, Tset+Tdead], l = :dash, label = :none, 
		color = :darkred)
	plot(p1, p2, layout = grid(2,1))
end

# ╔═╡ 6647a86f-7f6d-43d7-892e-724d3a191ca9
md"""

## Proportional (P) Control

$(Resource(control3_url, :width => 2800px))

### Description

The controller output is proportional to the error signal, which is the scaled difference between the setpoint and the process variable. 

```math
g(t) = K_p \frac{r - y(t)}{s} + p_0 
```

where ``K_p`` is proportional gain, ``r`` is the setpoint, ``y(t)`` is the output variable, ``s`` is the span, and ``p_0`` is the controller output with zero error. The purpose of the span is to set the output to maximum when the difference between the setpoint and the process variable exceeds the span. Furthermore, in practical application the output needs to be constrained between ``-1`` and ``1``.

```math
f(t) = \begin{cases}
-1 &  g(t) < -1 \\
1 & g(t) > 1 \\
g(t) & else \\
\end{cases}
```

The case statement ensures that output ranges from ``-1`` (here maximum heating) to ``+1`` (here maximum cooling). Finally the output is scaled to ``\pm 12V``, which corresponds to the operating voltages of the TEC element. 

### Implementation
"""

# ╔═╡ b40aefaa-4600-42f7-ab1d-d92b54fb6401
function simulation_P(T, n; Tset = 280.0, Kp = 1.4, span = 20.0, p0 = 0.0)
	dt = 1.0 
	ts = Float64[]
	Ts = Float64[]
	Vs = Float64[]
	push!(Ts, T)
	push!(Vs, 12.0)
	push!(ts, 0.0)
	for i = 1:n
		theT = Ts[end]
		theV = Vs[end]
		g =  Kp*(theT - Tset)/span + p0
		
		if g < -1
			MV = -1
		elseif g > 1
			MV = 1
		else
			MV = g
		end
		
		theV = 12.0*MV # The voltage changes between -12 and 12  
		newT = update_system(theT, theV, dt)
		push!(Ts, newT)
		push!(Vs, theV)
		push!(ts, ts[end] + dt)
	end

	return ts, Ts, Vs
end

# ╔═╡ a20f135e-f061-4287-9e11-3ffad5cc64b8
@bind P combine() do Child
	md"""
	``T_{set}`` $(
		Child(Slider(200:10:400, default = 250, show_value = true))
	) 
	
	``T_{span}`` $( 
		Child(Slider(1:1:40, default = 20, show_value = true))
	) ``K_p`` $( 
		Child(Slider(0:0.1:4, default = 2, show_value = true))
	) ``p_0`` $( 
		Child(Slider(-1:0.1:1, default = 0, show_value = true))
	) 

	
	"""
end

# ╔═╡ 177d0f02-9045-49d5-84cd-bc7b6ebb58fc
let 
	Tset = P[1]
	span = P[2]
	Kp = P[3]
	p0 = P[4]
	ts, Ts, Vs = simulation_P(300.0, 3600; Tset = Tset, Kp = Kp, span = span, p0)
	p1 = plot(ts./60.0, Vs, label = :none, color = :black, ylabel = "V")
	p2 = plot(ts./60.0, Ts, color = :black, ylabel = "T (K)", label = "T")
	plot!([0, ts[end]./60.0], [Tset, Tset], label = "Tset")
	plot(p1, p2, layout = grid(2,1), size= (700, 400))
end

# ╔═╡ 2a2f1d95-60d1-41b5-9d94-e69e7c5bba78
md"""

### Advantages

The proportional contontroller gradually changes the input to converge on the set point, which eliminates chatter. There are also no oscillations around the final value. 

### Disadvanges

The P-controller suffers from offset error. Offset error is the difference between the desired value and the actual value. Over a range of operating conditions, proportional control alone is unable to eliminate offset error, as it requires an error to generate an output adjustment. Although a proportional controller may be tuned by adjusting ``p_0`` for a specific operating condition, it cannot be eliminated over the entire state space. 
"""

# ╔═╡ 9e35dc47-ff08-4254-96dd-fe27c0c7366d
md"""
## Proportional-Integral (PI) Control

$(Resource(control3_url, :width => 2800px))

### Description

Including an integral term increases action in relation not only to the error but also the time for which it has persisted. The integral term can be used to eliminate the bias in the P-controller. 



```math
e(t) = \frac{r - y(t)}{s}
```

```math
g(t) = K_p e(t) + K_i \int_0^t e(\tau) d\tau  
```

where ``K_p`` is proportional gain, ``r`` is the setpoint, ``y(t)`` is the output variable, ``s`` is the span (these terms are the same as for the P-controller), and ``K_i`` is the the integral gain.

As with the P-controller, the purpose of the span is to set the output to maximum when the difference between the setpoint and the process variable exceeds the span. Furthermore, in practical application the output needs to be constrained between ``-1`` and ``1``.

```math
f(t) = \begin{cases}
-1 &  g(t) < -1 \\
1 & g(t) > 1 \\
g(t) & else \\
\end{cases}
```

The case statement ensures that output ranges from ``-1`` (here maximum heating) to ``+1`` (here maximum cooling). Finally the output is scaled to ``\pm 12V``, which corresponds to the operating voltages of the TEC element. 

### Implementation
"""

# ╔═╡ 6e2bc9b4-6b61-49c8-ae72-0bc94e72543a
function simulation_PI(T, n; Tset = 280.0, Kp = 1.4, span = 20.0, Ki = 1.0)
	dt = 1.0 
	ts = Float64[]
	Ts = Float64[]
	Vs = Float64[]
	integral = Float64[]
	push!(Ts, T)
	push!(Vs, 12.0)
	push!(ts, 0.0)
	push!(integral, 0.0)
	for i = 1:n
		theT = Ts[end]
		theV = Vs[end]
		error = (theT - Tset)/span
		theIntegral = integral[end] + error*Ki*dt
		MV = Kp*error + Ki*theIntegral
		
		if MV < -1
			MV = -1
		elseif MV > 1
			MV = 1
		end
	
		theV = 12.0*MV
		newT = update_system(theT, theV, dt)
		push!(Ts, newT)
		push!(Vs, theV)
		push!(integral, theIntegral)
		push!(ts, ts[end] + dt)
	end

	return ts, Ts, Vs, integral
end

# ╔═╡ bbbb2744-a2d9-412a-9938-e0a97aa2620b
@bind PI combine() do Child
	md"""
	``T_{set}`` $(
		Child(Slider(200:10:400, default = 250, show_value = true))
	) 
	
	``T_{span}`` $( 
		Child(Slider(1:1:40, default = 20, show_value = true))
	) ``K_p`` $( 
		Child(Slider(0:0.1:4, default = 2, show_value = true))
	) ``K_i`` $( 
		Child(Slider(0:0.1:4, default = 1.0, show_value = true))
	) 

	
	"""
end

# ╔═╡ fed350c9-aaa1-4a1a-9338-7f244b5e738b
let 
	Tset = PI[1]
	span = PI[2]
	Kp = PI[3]
	Ki = PI[4]
	ts, Ts, Vs, integral = simulation_PI(300.0, 3600; Tset = Tset, 
		span = span, Kp = Kp, Ki = Ki)
	p1 = plot(ts./60.0, Vs, label = :none, color = :black, ylabel = "V")
	p2 = plot(ts./60.0, Ts, color = :black, ylabel = "T (K)", label = "T")
	p2 = plot!([0, ts[end]./60.0], [Tset, Tset], label = "Tset")
	p3 = plot(ts./60.0, integral, color = :black, label = "Integral", 
		xlabel = "Time (min)")
	plot(p1, p2, p3, layout = grid(3,1), size = (700,500))
end

# ╔═╡ f4a47b15-3c2c-4f08-b611-08d57971b04f
md"""
### Advantages
The integral term can clearly eliminate the bias from the P-controller.

### Disadvantages
The I term can introduce osillations around the setpoint. The ``K_i`` value needs to be tuned for the system.
"""

# ╔═╡ 3fba7ef0-a994-4f7e-934a-cb475ceea441
md"""
## Proportional-Integral-Derivative (PID) Control
$(Resource(control3_url, :width => 2800px))

### Description

The derivative of the process error is calculated by determining the slope of the error over time and multiplying this rate of change by the derivative gain ``K_d``. Derivative action predicts system behavior and thus improves settling time and stability of the system.

The full PID controller equation is given by 

```math
e(t) = \frac{r - y(t)}{s}
```

```math
g(t) = K_p e(t)  + K_i \int_0^t e(\tau) d\tau + K_d \frac{de(t)}{dt}
```

where ``K_p`` is proportional gain, ``r`` is the setpoint, ``y(t)`` is the output variable, ``s`` is the span, ``K_i`` is the the integral gain (these terms are the same as for the PI-controller), and ``K_d`` is the derivative gain.

As with the PI-controller, the purpose of the span is to set the output to maximum when the difference between the setpoint and the process variable exceeds the span. Furthermore, in practical application the output needs to be constrained between ``-1`` and ``1``.

```math
f(t) = \begin{cases}
-1 &  g(t) < -1 \\
1 & g(t) > 1 \\
g(t) & else \\
\end{cases}
```

The case statement ensures that output ranges from ``-1`` (here maximum heating) to ``+1`` (here maximum cooling). Finally the output is scaled to ``\pm 12V``, which corresponds to the operating voltages of the TEC element. 

### Implementation
"""

# ╔═╡ 9c1588f1-b49d-470e-b71c-9e70bebafc25
function simulation_PID(T, n; Tset = 280.0, Kp = 1.4, span = 20.0, Ki = 1.0, Kd = 1.0)
	dt = 1.0 
	ts = Float64[]
	Ts = Float64[]
	Vs = Float64[]
	integral = Float64[]
	derivative = Float64[]
	push!(Ts, T)
	push!(Ts, T)
	push!(Vs, 12.0)
	push!(Vs, 12.0)
	push!(ts, 0.0)
	push!(ts, 1.0)
	push!(integral, 0.0)
	push!(integral, 0.0)
	push!(derivative, 0.0)
	push!(derivative, 0.0)
	for i = 1:n
		theT = Ts[end]
		theV = Vs[end]
		error = (Ts[end] - Tset)/span
		error_past = (Ts[end-1] - Tset)/span
		
		theIntegral = integral[end] + error*Ki*dt
		theDerivative = (error_past - error)/dt
		MV = Kp*error + Ki*theIntegral + Kd*theDerivative
		
		if MV < -1
			MV = -1
		elseif MV > 1
			MV = 1
		end

		theV = 12.0*MV
		newT = update_system(theT, theV, dt)
		push!(Ts, newT)
		push!(Vs, theV)
		push!(integral, theIntegral)
		push!(derivative, theDerivative)
		push!(ts, ts[end] + dt)
	end

	return ts, Ts, Vs, integral, derivative
end

# ╔═╡ 5fe29e57-fe90-4ae8-9beb-3662c51d9c16
@bind PID combine() do Child
	md"""
	``T_{set}`` $(
		Child(Slider(200:10:400, default = 250, show_value = true))
	) ``T_{span}`` $( 
		Child(Slider(1:1:40, default = 20, show_value = true))
	) 
	
	``K_p`` $( 
		Child(Slider(0:0.1:4, default = 2, show_value = true))
	) ``K_i`` $( 
		Child(Slider(0:0.1:4, default = 1.0, show_value = true))
	) ``K_d`` $( 
		Child(Slider(0:1.0:40, default = 0.0, show_value = true))
	) 

	
	"""
end

# ╔═╡ 537f07ab-f141-4a38-9dcd-be8de62fc3e5
let 
	Tset = PID[1]
	span = PID[2]
	Kp = PID[3]
	Ki = PID[4]
	Kd = PID[5]
	ts, Ts, Vs, integral, derivative = simulation_PID(300.0, 3600; Tset = Tset, 
		span = span, Kp = Kp, Ki = Ki, Kd = Kd)
	p1 = plot(ts./60.0, Vs, label = :none, color = :black, ylabel = "V")
	p2 = plot(ts./60.0, Ts, color = :black, ylabel = "T (K)", label = "T")
	p2 = plot!([0, ts[end]./60.0], [Tset, Tset], label = "Tset")
	p3 = plot(ts./60.0, integral, color = :black, label = "Integral")
	p4 = plot(ts./60.0, derivative, color = :black, label = "Derivative", 
	 	xlabel = "Time (min)")
	
	plot(p1, p2, p3, p4, layout = grid(4,1), size = (700,500))
end

# ╔═╡ 0a42d713-ecc8-41cb-90f0-30f3c598c1af
md"""
### Advantages
The derivative term can improve convergence rates to the setpoint.

### Disadvantages
Noise in derivative calculations can lead to error amplification. In many applications PI control is preferred to PID control.
"""

# ╔═╡ 4267d65e-1cfd-4fc1-ba61-3f15ba5885c6
md"""
## Trajactory Control
$(Resource(control4_url, :width => 2800px))

### Description

The standard PID controller operates with a fixed set point ``r``. However, the set point may itself be a function of time, ``r(t)``, thus forcing a temperature trajectory, rather than a fixed-point control. 

It is possible to try to force the system along the trajectory by updating ``r(t)`` at each time step. The example below tries to force the system with a linear cooling rate of 1 K min⁻¹.

"""

# ╔═╡ 06007dd6-94dc-4ed6-bf53-18a44db17c06
function simulation_PID_trajectory(
	T, n; Kp = 1.4, span = 20.0, Ki = 1.0, Kd = 1.0, cr = 1.0)

	dt = 1.0 
	ts = Float64[]
	Ts = Float64[]
	Vs = Float64[]
	Tset = Float64[]
	integral = Float64[]
	derivative = Float64[]
	push!(Ts, T)
	push!(Ts, T)
	push!(Vs, 12.0)
	push!(Vs, 12.0)
	push!(ts, 0.0)
	push!(ts, 1.0)
	push!(integral, 0.0)
	push!(integral, 0.0)
	push!(derivative, 0.0)
	push!(derivative, 0.0)
	push!(Tset, 300.0)
	push!(Tset, 300.0)
	for i = 1:n
		theT = Ts[end]
		theV = Vs[end]
		error = (Ts[end] - Tset[end])/span
		error_past = (Ts[end-1] - Tset[end-1])/span
		
		theIntegral = integral[end] + error*Ki*dt
		theDerivative = (error_past - error)/dt
		MV = Kp*error + Ki*theIntegral + Kd*theDerivative
		
		if MV < -1
			MV = -1
		elseif MV > 1
			MV = 1
		end

		theV = 12.0*MV
		newT = update_system(theT, theV, dt)
		newTset = Tset[end] - cr/60.0*dt
		push!(Ts, newT)
		push!(Vs, theV)
		push!(integral, theIntegral)
		push!(derivative, theDerivative)
		push!(Tset, newTset)
		push!(ts, ts[end] + dt)
	end

	return ts, Ts, Vs, integral, derivative, Tset
end

# ╔═╡ 6fc7e520-e85e-4b96-ae6a-1d1312e9e6c8
@bind PID_traj combine() do Child
	md"""
	``c_{r}\;[K\;min^{-1}]`` $( 
		Child(Slider(0:0.1:2, default = 1, show_value = true))
	) 
	
	``T_{span}`` $( 
		Child(Slider(1:1:40, default = 20, show_value = true))
	) 
	
	``K_p`` $( 
		Child(Slider(0:0.1:4, default = 2, show_value = true))
	) ``K_i`` $( 
		Child(Slider(0:0.1:4, default = 1.0, show_value = true))
	) ``K_d`` $( 
		Child(Slider(0:1.0:40, default = 0.0, show_value = true))
	) 

	
	"""
end

# ╔═╡ e2698160-39e6-4a76-ac17-6ccd56fb151f
let 
	cr = PID_traj[1]
	span = PID_traj[2]
	Kp = PID_traj[3]
	Ki = PID_traj[4]
	Kd = PID_traj[5]
	
	ts, Ts, Vs, integral, derivative, Tset = simulation_PID_trajectory(
		300.0, 3600; span = span, Kp = Kp, Ki = Ki, Kd = Kd, cr = cr)
	p1 = plot(ts./60.0, Vs, label = :none, color = :black, ylabel = "V")
	p2 = plot(ts./60.0, Ts, color = :black, ylabel = "T (K)", label = "T")
	p2 = plot!(ts./60.0, Tset, label = "Tset")
	p3 = plot(ts./60.0, integral, color = :black, label = "Integral")
	p4 = plot(ts./60.0, derivative, color = :black, label = "Derivative", 
	 	xlabel = "Time (min)")
	
	plot(p1, p2, p3, p4, layout = grid(4,1), size = (700,500))
end

# ╔═╡ 2ae4f6e6-a1f0-4618-b0a2-ca3e4c73ee7f
md"""
For this particular system, forcing a linear profile is easy. However, oscillations may occur for ``K_i`` and ``K_d`` settings, particularly for small span values. Tuned PID parameters (see more below) may be different from the constant set-point case. 
"""

# ╔═╡ d3780235-46e6-472c-9f46-18ac5cf8ee40
md"""
## Hardware Controllers

Many hardware controllers have on-board PID capabilities. The picture shows a TE Technology TC-36-25-RS232 device, which is a bi-polar proportional-integral-derivative temperature controller that can modulate power input to a thermolectric device. It communicates through an RS 232 port. 

$(Resource(control5_url, :width => 2800px))

The controller stores the ``T_{set}``, ``T_{span}``, ``K_p``, ``K_i``, and ``K_d`` values in the unit's memory. The values can be changed through serial commands passed to the controller. The unit takes fixed voltage power as input provides regulated output (``\pm 100\%`` of the input) to a TEC module. The advantage of hardware controllers is that they can operate offline as part of an instrument. 
"""

# ╔═╡ 945aba6b-ad67-44e7-ae6b-50cff0ac014a
md"""
## PID Tuning

PID parameters can be tuned either on the physical system, or by simulating the system as we did above. Manual tuning is common. One tuning method is to first set ``K_{i}`` and ``K_{d}`` values to zero. Next, increase the ``K_{p}`` value until oscillations are observed. Then set ``K_{p}`` to approximately half that value. Next, increase ``K_{i}`` until any offset is corrected in sufficient time for the process, but not until too great a value causes instability. Finally, increase ``K_{d}``, if required, until the loop is acceptably quick to reach its reference after a load disturbance. 
"""

# ╔═╡ 57d40abd-2a35-468a-9334-f63d962ba604
md"""
# Some Key Concepts in Systems Control 

## Mutli-Input Control System

SISO - Single Input, Single Output

These systems use data/input from one sensor to control one output. These are the simplest to design since they correspond one sensor to one actuator. For example, temperature (TC) is used to control the valve state of v1 through a PID controller.

SIMO - Single Input, Multiple Output

These systems use data/input from one sensor to control multiple outputs. For example, temperature (TC) is used to control the valve state of v1 and v2 through PID controllers.

MISO - Multiple Input, Single Output

These systems use data/input from multiple sensors to control one ouput. For example, a cascade controller can be considered MISO. Temperature (TC) is used in a PID controller (#1) to determine a flow rate set point i.e. FCset. With the FCset and FC controller, they are used to control the valve state of v1 through a PID controller (#2).

MIMO - Multiple Input, Multiple Output

These systems use data/input from multiple sensors to control multiple outputs. These are usually the hardest to design since multiple sensor data is integrated to coordinate multiple actuators. For example, flow rate (FC) and temperature (TC) are used to control multiple valves (v1, v2, and v3). Often, MIMO systems are not PID controllers but rather designed for a specific situation.

## Classification of Systems

- Continuous Linear Time-Invariant Systems (LTI Systems)

```math
\begin{eqnarray}
 & \quad \vec{q}'(t) &= \mathbf{A}\vec{q}(t) + \mathbf{B} \vec{f}(t) \\
 & \quad \vec{y}(t) &=  \mathbf{C}\vec{q}(t) + \mathbf{D} \vec{f}(t) \\
\end{eqnarray}
```

- Continuous Linear Time-Variant (LTV Systems)

```math
\begin{eqnarray}
 & \quad \vec{q}'(t) &= \mathbf{A}(t)\vec{q}(t) + \mathbf{B}(t) \vec{f}(t) \\
 & \quad \vec{y}(t) &=  \mathbf{C}(t)\vec{q}(t) + \mathbf{D}(t) \vec{f}(t) \\
\end{eqnarray}
```

- Non-linear systems

## Controllability and Observability
Controllability and observability represent two major concepts of modern control
system theory. They can be roughly defined as follows.
"""

# ╔═╡ 0d40bd72-6be9-4127-9c63-6041473a3ccc
Markdown.MD(
	Markdown.Admonition("warning", "Key Concepts", [md"
**Controllability:** In order to be able to do whatever we want with the given
dynamic system under control input, the system must be controllable.

**Observability:** In order to see what is going on inside the system under observation, the system must be observable.
	"]))

# ╔═╡ b9f569a7-3854-40c8-8e64-de13f5eb19cf
md"""
For linear systems, controllability and observability are determined by the matrices ``\mathbf{A}`` and ``\mathbf{B}``.

The controllability matrix for LTI systems is given by

```math
 \mathbf{R}={\begin{bmatrix}\mathbf{B}&\mathbf{AB}&\mathbf{A^{{2}}B}&...&\mathbf{A}^{{n-1}}\mathbf{B}\end{bmatrix}}
```

The system is controllable if the controllability matrix has full row rank. The solution is more difficult for LTV systems, but remains closely related to the matrices ``\mathbf{A}`` and ``\mathbf{B}``
"""

# ╔═╡ 4af334c0-c8bd-416f-956e-6c702a6b5f01
md"""

## Optimal Control

Optimal control theory is a branch of control theory that deals with finding a control for a dynamical system over a period of time such that an objective function is optimized. For example, the dynamical system might be a spacecraft with controls corresponding to rocket thrusters, and the objective might be to reach the Moon with minimum fuel expenditure

"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
DifferentialEquations = "0c46a032-eb83-5123-abaf-570d42b7fbaa"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
SymPy = "24249f21-da20-56a4-8eb1-6a02cf4ae2e6"

[compat]
DifferentialEquations = "~7.9.1"
Plots = "~1.39.0"
PlutoUI = "~0.7.52"
SymPy = "~1.1.12"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.10.4"
manifest_format = "2.0"
project_hash = "b79a323e77e55d0c5529a7430059e8749c559c2a"

[[deps.ADTypes]]
git-tree-sha1 = "016833eb52ba2d6bea9fcb50ca295980e728ee24"
uuid = "47edcb42-4c32-4615-8424-f2b9edc5f35b"
version = "0.2.7"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "6e1d2a35f2f90a4bc7c2ed98079b2ba09c35b83a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.2"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "cde29ddf7e5726c9fb511f340244ea3481267608"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.7.2"
weakdeps = ["StaticArrays"]

    [deps.Adapt.extensions]
    AdaptStaticArraysExt = "StaticArrays"

[[deps.AliasTables]]
deps = ["PtrArrays", "Random"]
git-tree-sha1 = "9876e1e164b144ca45e9e3198d0b689cadfed9ff"
uuid = "66dad0bd-aa9a-41b7-9441-69ab47430ed8"
version = "1.1.3"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "d57bd3762d308bded22c3b82d033bff85f6195c6"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.4.0"

[[deps.ArrayInterface]]
deps = ["Adapt", "LinearAlgebra", "Requires", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "c5aeb516a84459e0318a02507d2261edad97eb75"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "7.7.1"

    [deps.ArrayInterface.extensions]
    ArrayInterfaceBandedMatricesExt = "BandedMatrices"
    ArrayInterfaceBlockBandedMatricesExt = "BlockBandedMatrices"
    ArrayInterfaceCUDAExt = "CUDA"
    ArrayInterfaceGPUArraysCoreExt = "GPUArraysCore"
    ArrayInterfaceStaticArraysCoreExt = "StaticArraysCore"
    ArrayInterfaceTrackerExt = "Tracker"

    [deps.ArrayInterface.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

[[deps.ArrayLayouts]]
deps = ["FillArrays", "LinearAlgebra"]
git-tree-sha1 = "ce2ca959f932f5dad70697dd93133d1167cf1e4e"
uuid = "4c555306-a7a7-4459-81d9-ec55ddd5c99a"
version = "1.10.2"
weakdeps = ["SparseArrays"]

    [deps.ArrayLayouts.extensions]
    ArrayLayoutsSparseArraysExt = "SparseArrays"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.BandedMatrices]]
deps = ["ArrayLayouts", "FillArrays", "LinearAlgebra", "PrecompileTools"]
git-tree-sha1 = "0b816941273b5b162be122a6c94d706e3b3125ca"
uuid = "aae01518-5342-5314-be14-df237901396f"
version = "0.17.38"
weakdeps = ["SparseArrays"]

    [deps.BandedMatrices.extensions]
    BandedMatricesSparseArraysExt = "SparseArrays"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BitFlags]]
git-tree-sha1 = "0691e34b3bb8be9307330f88d1a3c3f25466c24d"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.9"

[[deps.BitTwiddlingConvenienceFunctions]]
deps = ["Static"]
git-tree-sha1 = "f21cfd4950cb9f0587d5067e69405ad2acd27b87"
uuid = "62783981-4cbd-42fc-bca8-16325de8dc4b"
version = "0.1.6"

[[deps.BoundaryValueDiffEq]]
deps = ["ArrayInterface", "BandedMatrices", "DiffEqBase", "FiniteDiff", "ForwardDiff", "LinearAlgebra", "NonlinearSolve", "Reexport", "SciMLBase", "Setfield", "SparseArrays", "TruncatedStacktraces", "UnPack"]
git-tree-sha1 = "f7392ce20e6dafa8fee406142b1764de7d7cd911"
uuid = "764a87c0-6b3e-53db-9096-fe964310641d"
version = "4.0.1"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9e2a6b69137e6969bab0152632dcb3bc108c8bdd"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+1"

[[deps.CEnum]]
git-tree-sha1 = "389ad5c84de1ae7cf0e28e381131c98ea87d54fc"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.5.0"

[[deps.CPUSummary]]
deps = ["CpuId", "IfElse", "PrecompileTools", "Static"]
git-tree-sha1 = "5a97e67919535d6841172016c9530fd69494e5ec"
uuid = "2a0fbf3d-bb9c-48f3-b0a9-814d99fd7ab9"
version = "0.2.6"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "a2f1c8c668c8e3cb4cca4e57a8efdb09067bb3fd"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.18.0+2"

[[deps.Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f641eb0a4f00c343bbc32346e1217b86f3ce9dad"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.1"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra"]
git-tree-sha1 = "71acdbf594aab5bbb2cec89b208c41b4c411e49f"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.24.0"
weakdeps = ["SparseArrays"]

    [deps.ChainRulesCore.extensions]
    ChainRulesCoreSparseArraysExt = "SparseArrays"

[[deps.CloseOpenIntervals]]
deps = ["Static", "StaticArrayInterface"]
git-tree-sha1 = "05ba0d07cd4fd8b7a39541e31a7b0254704ea581"
uuid = "fb6a15b2-703c-40df-9091-08a04967cfa9"
version = "0.1.13"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "b8fe8546d52ca154ac556809e10c75e6e7430ac8"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.5"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "b5278586822443594ff615963b0c09755771b3e0"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.26.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "b10d0b65641d57b8b4d5e234446582de5047050d"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.5"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Requires", "Statistics", "TensorCore"]
git-tree-sha1 = "a1f44953f2382ebb937d60dafbe2deea4bd23249"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.10.0"
weakdeps = ["SpecialFunctions"]

    [deps.ColorVectorSpace.extensions]
    SpecialFunctionsExt = "SpecialFunctions"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "362a287c3aa50601b0bc359053d5c2468f0e7ce0"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.11"

[[deps.CommonEq]]
git-tree-sha1 = "6b0f0354b8eb954cdba708fb262ef00ee7274468"
uuid = "3709ef60-1bee-4518-9f2f-acd86f176c50"
version = "0.2.1"

[[deps.CommonSolve]]
git-tree-sha1 = "0eee5eb66b1cf62cd6ad1b460238e60e4b09400c"
uuid = "38540f10-b2f7-11e9-35d8-d573e4eb0ff2"
version = "0.2.4"

[[deps.CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "8ae8d32e09f0dcf42a36b90d4e17f5dd2e4c4215"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.16.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.1+0"

[[deps.ConcreteStructs]]
git-tree-sha1 = "f749037478283d372048690eb3b5f92a79432b34"
uuid = "2569d6c7-a4a2-43d3-a901-331e8e4be471"
version = "0.2.3"

[[deps.ConcurrentUtilities]]
deps = ["Serialization", "Sockets"]
git-tree-sha1 = "ea32b83ca4fefa1768dc84e504cc0a94fb1ab8d1"
uuid = "f0e56b4a-5159-44fe-b623-3e5288b988bb"
version = "2.4.2"

[[deps.Conda]]
deps = ["Downloads", "JSON", "VersionParsing"]
git-tree-sha1 = "b19db3927f0db4151cb86d073689f2428e524576"
uuid = "8f4d0f93-b110-5947-807f-2305c1781a2d"
version = "1.10.2"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "d8a9c0b6ac2d9081bf76324b39c78ca3ce4f0c98"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.5.6"

    [deps.ConstructionBase.extensions]
    ConstructionBaseIntervalSetsExt = "IntervalSets"
    ConstructionBaseStaticArraysExt = "StaticArrays"

    [deps.ConstructionBase.weakdeps]
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.Contour]]
git-tree-sha1 = "439e35b0b36e2e5881738abc8857bd92ad6ff9a8"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.6.3"

[[deps.CpuId]]
deps = ["Markdown"]
git-tree-sha1 = "fcbb72b032692610bfbdb15018ac16a36cf2e406"
uuid = "adafc99b-e345-5852-983c-f28acb93d879"
version = "0.3.1"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "1d0a14036acb104d9e89698bd408f63ab58cdc82"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.20"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Dbus_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "fc173b380865f70627d7dd1190dc2fce6cc105af"
uuid = "ee1fde0b-3d02-5ea6-8484-8dfef6360eab"
version = "1.14.10+0"

[[deps.DelayDiffEq]]
deps = ["ArrayInterface", "DataStructures", "DiffEqBase", "LinearAlgebra", "Logging", "OrdinaryDiffEq", "Printf", "RecursiveArrayTools", "Reexport", "SciMLBase", "SimpleNonlinearSolve", "SimpleUnPack"]
git-tree-sha1 = "e40378efd2af7658d0a0579aa9e15b17137368f4"
uuid = "bcd4f6db-9728-5f36-b5f7-82caef46ccdb"
version = "5.44.0"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
git-tree-sha1 = "9e2f36d3c96a820c678f2f1f1782582fcf685bae"
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"
version = "1.9.1"

[[deps.DiffEqBase]]
deps = ["ArrayInterface", "ChainRulesCore", "DataStructures", "DocStringExtensions", "EnumX", "FastBroadcast", "ForwardDiff", "FunctionWrappers", "FunctionWrappersWrappers", "LinearAlgebra", "Logging", "Markdown", "MuladdMacro", "Parameters", "PreallocationTools", "PrecompileTools", "Printf", "RecursiveArrayTools", "Reexport", "Requires", "SciMLBase", "SciMLOperators", "Setfield", "SparseArrays", "Static", "StaticArraysCore", "Statistics", "Tricks", "TruncatedStacktraces", "ZygoteRules"]
git-tree-sha1 = "0d9982e8dee851d519145857e79a17ee33ede154"
uuid = "2b5f629d-d688-5b77-993f-72d75c75574e"
version = "6.130.0"

    [deps.DiffEqBase.extensions]
    DiffEqBaseDistributionsExt = "Distributions"
    DiffEqBaseGeneralizedGeneratedExt = "GeneralizedGenerated"
    DiffEqBaseMPIExt = "MPI"
    DiffEqBaseMeasurementsExt = "Measurements"
    DiffEqBaseMonteCarloMeasurementsExt = "MonteCarloMeasurements"
    DiffEqBaseReverseDiffExt = "ReverseDiff"
    DiffEqBaseTrackerExt = "Tracker"
    DiffEqBaseUnitfulExt = "Unitful"
    DiffEqBaseZygoteExt = "Zygote"

    [deps.DiffEqBase.weakdeps]
    Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
    GeneralizedGenerated = "6b9d7cbe-bcb9-11e9-073f-15a7a543e2eb"
    MPI = "da04e1cc-30fd-572f-bb4f-1f8673147195"
    Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
    MonteCarloMeasurements = "0987c9cc-fe09-11e8-30f0-b96dd679fdca"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"
    Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[[deps.DiffEqCallbacks]]
deps = ["DataStructures", "DiffEqBase", "ForwardDiff", "Functors", "LinearAlgebra", "Markdown", "NLsolve", "Parameters", "RecipesBase", "RecursiveArrayTools", "SciMLBase", "StaticArraysCore"]
git-tree-sha1 = "d0b94b3694d55e7eedeee918e7daee9e3b873399"
uuid = "459566f4-90b8-5000-8ac3-15dfb0a30def"
version = "2.35.0"
weakdeps = ["OrdinaryDiffEq", "Sundials"]

[[deps.DiffEqNoiseProcess]]
deps = ["DiffEqBase", "Distributions", "GPUArraysCore", "LinearAlgebra", "Markdown", "Optim", "PoissonRandom", "QuadGK", "Random", "Random123", "RandomNumbers", "RecipesBase", "RecursiveArrayTools", "ResettableStacks", "SciMLBase", "StaticArraysCore", "Statistics"]
git-tree-sha1 = "ab1e6515ce15f01316a9825b02729fefa51726bd"
uuid = "77a26b50-5914-5dd7-bc55-306e6241c503"
version = "5.23.0"

    [deps.DiffEqNoiseProcess.extensions]
    DiffEqNoiseProcessReverseDiffExt = "ReverseDiff"

    [deps.DiffEqNoiseProcess.weakdeps]
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "23163d55f885173722d1e4cf0f6110cdbaf7e272"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.15.1"

[[deps.DifferentialEquations]]
deps = ["BoundaryValueDiffEq", "DelayDiffEq", "DiffEqBase", "DiffEqCallbacks", "DiffEqNoiseProcess", "JumpProcesses", "LinearAlgebra", "LinearSolve", "NonlinearSolve", "OrdinaryDiffEq", "Random", "RecursiveArrayTools", "Reexport", "SciMLBase", "SteadyStateDiffEq", "StochasticDiffEq", "Sundials"]
git-tree-sha1 = "c3d11164d1b08c379bc3c6abae45fcd7250e8e35"
uuid = "0c46a032-eb83-5123-abaf-570d42b7fbaa"
version = "7.9.1"

[[deps.Distances]]
deps = ["LinearAlgebra", "Statistics", "StatsAPI"]
git-tree-sha1 = "66c4c81f259586e8f002eacebc177e1fb06363b0"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.11"
weakdeps = ["ChainRulesCore", "SparseArrays"]

    [deps.Distances.extensions]
    DistancesChainRulesCoreExt = "ChainRulesCore"
    DistancesSparseArraysExt = "SparseArrays"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Distributions]]
deps = ["AliasTables", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns"]
git-tree-sha1 = "0e0a1264b0942f1f3abb2b30891f2a590cc652ac"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.110"

    [deps.Distributions.extensions]
    DistributionsChainRulesCoreExt = "ChainRulesCore"
    DistributionsDensityInterfaceExt = "DensityInterface"
    DistributionsTestExt = "Test"

    [deps.Distributions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    DensityInterface = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
    Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.DualNumbers]]
deps = ["Calculus", "NaNMath", "SpecialFunctions"]
git-tree-sha1 = "5837a837389fccf076445fce071c8ddaea35a566"
uuid = "fa6b7ba4-c1ee-5f82-b5fc-ecf0adba8f74"
version = "0.6.8"

[[deps.EnumX]]
git-tree-sha1 = "bdb1942cd4c45e3c678fd11569d5cccd80976237"
uuid = "4e289a0a-7415-4d19-859d-a7e5c4648b56"
version = "1.0.4"

[[deps.EnzymeCore]]
git-tree-sha1 = "1bc328eec34ffd80357f84a84bb30e4374e9bd60"
uuid = "f151be2c-9106-41f4-ab19-57ee4f262869"
version = "0.6.6"
weakdeps = ["Adapt"]

    [deps.EnzymeCore.extensions]
    AdaptExt = "Adapt"

[[deps.EpollShim_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8e9441ee83492030ace98f9789a654a6d0b1f643"
uuid = "2702e6a9-849d-5ed8-8c21-79e8b8f9ee43"
version = "0.0.20230411+0"

[[deps.ExceptionUnwrapping]]
deps = ["Test"]
git-tree-sha1 = "dcb08a0d93ec0b1cdc4af184b26b591e9695423a"
uuid = "460bff9d-24e4-43bc-9d9f-a8973cb893f4"
version = "0.1.10"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1c6317308b9dc757616f0b5cb379db10494443a7"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.6.2+0"

[[deps.ExponentialUtilities]]
deps = ["Adapt", "ArrayInterface", "GPUArraysCore", "GenericSchur", "LinearAlgebra", "PrecompileTools", "Printf", "SparseArrays", "libblastrampoline_jll"]
git-tree-sha1 = "8e18940a5ba7f4ddb41fe2b79b6acaac50880a86"
uuid = "d4d017d3-3776-5f7e-afef-a10c40355c18"
version = "1.26.1"

[[deps.ExprTools]]
git-tree-sha1 = "27415f162e6028e81c72b82ef756bf321213b6ec"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.10"

[[deps.FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "466d45dc38e15794ec7d5d63ec03d776a9aff36e"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.4+1"

[[deps.FastBroadcast]]
deps = ["ArrayInterface", "LinearAlgebra", "Polyester", "Static", "StaticArrayInterface", "StrideArraysCore"]
git-tree-sha1 = "a6e756a880fc419c8b41592010aebe6a5ce09136"
uuid = "7034ab61-46d4-4ed7-9d0f-46aef9175898"
version = "0.2.8"

[[deps.FastClosures]]
git-tree-sha1 = "acebe244d53ee1b461970f8910c235b259e772ef"
uuid = "9aa1b823-49e4-5ca5-8b0f-3971ec8bab6a"
version = "0.3.2"

[[deps.FastLapackInterface]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "cbf5edddb61a43669710cbc2241bc08b36d9e660"
uuid = "29a986be-02c6-4525-aec4-84b980013641"
version = "2.0.4"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FillArrays]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "0653c0a2396a6da5bc4766c43041ef5fd3efbe57"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.11.0"
weakdeps = ["PDMats", "SparseArrays", "Statistics"]

    [deps.FillArrays.extensions]
    FillArraysPDMatsExt = "PDMats"
    FillArraysSparseArraysExt = "SparseArrays"
    FillArraysStatisticsExt = "Statistics"

[[deps.FiniteDiff]]
deps = ["ArrayInterface", "LinearAlgebra", "Requires", "Setfield", "SparseArrays"]
git-tree-sha1 = "2de436b72c3422940cbe1367611d137008af7ec3"
uuid = "6a86dc24-6348-571c-b903-95158fe2bd41"
version = "2.23.1"

    [deps.FiniteDiff.extensions]
    FiniteDiffBandedMatricesExt = "BandedMatrices"
    FiniteDiffBlockBandedMatricesExt = "BlockBandedMatrices"
    FiniteDiffStaticArraysExt = "StaticArrays"

    [deps.FiniteDiff.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Zlib_jll"]
git-tree-sha1 = "db16beca600632c95fc8aca29890d83788dd8b23"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.96+0"

[[deps.Format]]
git-tree-sha1 = "9c68794ef81b08086aeb32eeaf33531668d5f5fc"
uuid = "1fa38f19-a742-5d3f-a2b9-30dd87b9d5f8"
version = "1.3.7"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "cf0fe81336da9fb90944683b8c41984b08793dad"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.36"
weakdeps = ["StaticArrays"]

    [deps.ForwardDiff.extensions]
    ForwardDiffStaticArraysExt = "StaticArrays"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "5c1d8ae0efc6c2e7b1fc502cbe25def8f661b7bc"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.13.2+0"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1ed150b39aebcc805c26b93a8d0122c940f64ce2"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.14+0"

[[deps.FunctionWrappers]]
git-tree-sha1 = "d62485945ce5ae9c0c48f124a84998d755bae00e"
uuid = "069b7b12-0de2-55c6-9aab-29f3d0a68a2e"
version = "1.1.3"

[[deps.FunctionWrappersWrappers]]
deps = ["FunctionWrappers"]
git-tree-sha1 = "b104d487b34566608f8b4e1c39fb0b10aa279ff8"
uuid = "77dc65aa-8811-40c2-897b-53d922fa7daf"
version = "0.1.3"

[[deps.Functors]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "64d8e93700c7a3f28f717d265382d52fac9fa1c1"
uuid = "d9f16b24-f501-4c13-a1f2-28368ffc5196"
version = "0.4.12"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll", "libdecor_jll", "xkbcommon_jll"]
git-tree-sha1 = "532f9126ad901533af1d4f5c198867227a7bb077"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.4.0+1"

[[deps.GPUArraysCore]]
deps = ["Adapt"]
git-tree-sha1 = "2d6ca471a6c7b536127afccfa7564b5b39227fe0"
uuid = "46192b85-c4d5-4398-a991-12ede77f4527"
version = "0.1.5"

[[deps.GR]]
deps = ["Artifacts", "Base64", "DelimitedFiles", "Downloads", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Preferences", "Printf", "Random", "Serialization", "Sockets", "TOML", "Tar", "Test", "UUIDs", "p7zip_jll"]
git-tree-sha1 = "27442171f28c952804dede8ff72828a96f2bfc1f"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.72.10"

[[deps.GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "FreeType2_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Qt6Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "025d171a2847f616becc0f84c8dc62fe18f0f6dd"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.72.10+0"

[[deps.GenericSchur]]
deps = ["LinearAlgebra", "Printf"]
git-tree-sha1 = "af49a0851f8113fcfae2ef5027c6d49d0acec39b"
uuid = "c145ed77-6b09-5dd9-b285-bf645a82121e"
version = "0.5.4"

[[deps.Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Zlib_jll"]
git-tree-sha1 = "7c82e6a6cd34e9d935e9aa4051b66c6ff3af59ba"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.80.2+0"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[deps.Graphs]]
deps = ["ArnoldiMethod", "Compat", "DataStructures", "Distributed", "Inflate", "LinearAlgebra", "Random", "SharedArrays", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "ebd18c326fa6cee1efb7da9a3b45cf69da2ed4d9"
uuid = "86223c79-3864-5bf0-83f7-82e725a168b6"
version = "1.11.2"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HTTP]]
deps = ["Base64", "CodecZlib", "ConcurrentUtilities", "Dates", "ExceptionUnwrapping", "Logging", "LoggingExtras", "MbedTLS", "NetworkOptions", "OpenSSL", "Random", "SimpleBufferStream", "Sockets", "URIs", "UUIDs"]
git-tree-sha1 = "d1d712be3164d61d1fb98e7ce9bcbc6cc06b45ed"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.10.8"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[deps.HostCPUFeatures]]
deps = ["BitTwiddlingConvenienceFunctions", "IfElse", "Libdl", "Static"]
git-tree-sha1 = "8e070b599339d622e9a081d17230d74a5c473293"
uuid = "3e5b6fbb-0976-4d2c-9146-d79de83f2fb0"
version = "0.1.17"

[[deps.HypergeometricFunctions]]
deps = ["DualNumbers", "LinearAlgebra", "OpenLibm_jll", "SpecialFunctions"]
git-tree-sha1 = "f218fe3736ddf977e0e772bc9a586b2383da2685"
uuid = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
version = "0.3.23"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "7134810b1afce04bbc1045ca1985fbe81ce17653"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.5"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "b6d6bfdd7ce25b0f9b2f6b3dd56b2673a66c8770"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.5"

[[deps.IfElse]]
git-tree-sha1 = "debdd00ffef04665ccbb3e150747a77560e8fad1"
uuid = "615f187c-cbe4-4ef1-ba3b-2fcf58d6d173"
version = "0.1.1"

[[deps.Inflate]]
git-tree-sha1 = "d1b1b796e47d94588b3757fe84fbf65a5ec4a80d"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.5"

[[deps.IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "14eb2b542e748570b56446f4c50fbfb2306ebc45"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2024.2.0+0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.IrrationalConstants]]
git-tree-sha1 = "630b497eafcc20001bba38a4651b327dcfc491d2"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.2"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLFzf]]
deps = ["Pipe", "REPL", "Random", "fzf_jll"]
git-tree-sha1 = "a53ebe394b71470c7f97c2e7e170d51df21b17af"
uuid = "1019f520-868f-41f5-a6de-eb00f4b6a39c"
version = "0.1.7"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "7e5d6779a1e09a36db2a7b6cff50942a0a7d0fca"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.5.0"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c84a835e1a09b289ffcd2271bf2a337bbdda6637"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.0.3+0"

[[deps.JumpProcesses]]
deps = ["ArrayInterface", "DataStructures", "DiffEqBase", "DocStringExtensions", "FunctionWrappers", "Graphs", "LinearAlgebra", "Markdown", "PoissonRandom", "Random", "RandomNumbers", "RecursiveArrayTools", "Reexport", "SciMLBase", "StaticArrays", "UnPack"]
git-tree-sha1 = "c451feb97251965a9fe40bacd62551a72cc5902c"
uuid = "ccbc3e58-028d-4f4c-8cd5-9ae44345cda5"
version = "9.10.1"
weakdeps = ["FastBroadcast"]

    [deps.JumpProcesses.extensions]
    JumpProcessFastBroadcastExt = "FastBroadcast"

[[deps.KLU]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse_jll"]
git-tree-sha1 = "884c2968c2e8e7e6bf5956af88cb46aa745c854b"
uuid = "ef3ab10e-7fda-4108-b977-705223b18434"
version = "0.4.1"

[[deps.Krylov]]
deps = ["LinearAlgebra", "Printf", "SparseArrays"]
git-tree-sha1 = "267dad6b4b7b5d529c76d40ff48d33f7e94cb834"
uuid = "ba0b0d4f-ebba-5204-a429-3ac8c609bfb7"
version = "0.9.6"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "170b660facf5df5de098d866564877e119141cbd"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.2+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bf36f528eec6634efc60d7ec062008f171071434"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "3.0.0+1"

[[deps.LLVMOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "d986ce2d884d49126836ea94ed5bfb0f12679713"
uuid = "1d63c593-3942-5779-bab2-d838dc0a180e"
version = "15.0.7+0"

[[deps.LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "70c5da094887fd2cae843b8db33920bac4b6f07d"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.2+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "50901ebc375ed41dbf8058da26f9de442febbbec"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.1"

[[deps.Latexify]]
deps = ["Format", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "OrderedCollections", "Requires"]
git-tree-sha1 = "ce5f5621cac23a86011836badfedf664a612cee4"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.16.5"

    [deps.Latexify.extensions]
    DataFramesExt = "DataFrames"
    SparseArraysExt = "SparseArrays"
    SymEngineExt = "SymEngine"

    [deps.Latexify.weakdeps]
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    SymEngine = "123dc426-2d89-5057-bbad-38513e3affd8"

[[deps.LayoutPointers]]
deps = ["ArrayInterface", "LinearAlgebra", "ManualMemory", "SIMDTypes", "Static", "StaticArrayInterface"]
git-tree-sha1 = "a9eaadb366f5493a5654e843864c13d8b107548c"
uuid = "10f19ff3-798f-405d-979b-55457f8fc047"
version = "0.1.17"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[deps.LevyArea]]
deps = ["LinearAlgebra", "Random", "SpecialFunctions"]
git-tree-sha1 = "56513a09b8e0ae6485f34401ea9e2f31357958ec"
uuid = "2d8b4e74-eb68-11e8-0fb9-d5eb67b50637"
version = "1.0.0"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.4.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.6.4+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[deps.Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll"]
git-tree-sha1 = "9fd170c4bbfd8b935fdc5f8b7aa33532c991a673"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.11+0"

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "6f73d1dd803986947b2c750138528a999a6c7733"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.6.0+0"

[[deps.Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "fbb1f2bef882392312feb1ede3615ddc1e9b99ed"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.49.0+0"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "f9557a255370125b405568f9767d6d195822a175"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.17.0+0"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "0c4f9c4f1a50d8f35048fa0532dabbadf702f81e"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.40.1+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "XZ_jll", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "2da088d113af58221c52828a80378e16be7d037a"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.5.1+1"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "5ee6203157c120d79034c748a2acba45b82b8807"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.40.1+0"

[[deps.LineSearches]]
deps = ["LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "Printf"]
git-tree-sha1 = "e4c3be53733db1051cc15ecf573b1042b3a712a1"
uuid = "d3d80556-e9d4-5f37-9878-2ab0fcc64255"
version = "7.3.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LinearSolve]]
deps = ["ArrayInterface", "ConcreteStructs", "DocStringExtensions", "EnumX", "EnzymeCore", "FastLapackInterface", "GPUArraysCore", "InteractiveUtils", "KLU", "Krylov", "Libdl", "LinearAlgebra", "MKL_jll", "PrecompileTools", "Preferences", "RecursiveFactorization", "Reexport", "Requires", "SciMLBase", "SciMLOperators", "Setfield", "SparseArrays", "Sparspak", "SuiteSparse", "UnPack"]
git-tree-sha1 = "9f27ba34f5821a0495efb09ea3a465c31326495a"
uuid = "7ed4a6bd-45f5-4d41-b270-4a48e9bafcae"
version = "2.10.0"

    [deps.LinearSolve.extensions]
    LinearSolveBlockDiagonalsExt = "BlockDiagonals"
    LinearSolveCUDAExt = "CUDA"
    LinearSolveEnzymeExt = "Enzyme"
    LinearSolveHYPREExt = "HYPRE"
    LinearSolveIterativeSolversExt = "IterativeSolvers"
    LinearSolveKernelAbstractionsExt = "KernelAbstractions"
    LinearSolveKrylovKitExt = "KrylovKit"
    LinearSolveMetalExt = "Metal"
    LinearSolvePardisoExt = "Pardiso"

    [deps.LinearSolve.weakdeps]
    BlockDiagonals = "0a1fb500-61f7-11e9-3c65-f5ef3456f9f0"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"
    HYPRE = "b5ffcf37-a2bd-41ab-a3da-4bd9bc8ad771"
    IterativeSolvers = "42fd0dbc-a981-5370-80f2-aaf504508153"
    KernelAbstractions = "63c18a36-062a-441e-b654-da1e3ab1ce7c"
    KrylovKit = "0b1a1467-8014-51b9-945f-bf0ae24f4b77"
    Metal = "dde4c033-4e86-420c-a63e-0dd931031962"
    Pardiso = "46dd5b70-b6fb-5a00-ae2d-e8fea33afaf2"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "a2d09619db4e765091ee5c6ffe8872849de0feea"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.28"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "c1dd6d7978c12545b4179fb6153b9250c96b0075"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.0.3"

[[deps.LoopVectorization]]
deps = ["ArrayInterface", "CPUSummary", "CloseOpenIntervals", "DocStringExtensions", "HostCPUFeatures", "IfElse", "LayoutPointers", "LinearAlgebra", "OffsetArrays", "PolyesterWeave", "PrecompileTools", "SIMDTypes", "SLEEFPirates", "Static", "StaticArrayInterface", "ThreadingUtilities", "UnPack", "VectorizationBase"]
git-tree-sha1 = "8084c25a250e00ae427a379a5b607e7aed96a2dd"
uuid = "bdcacae8-1622-11e9-2a5c-532679323890"
version = "0.12.171"
weakdeps = ["ChainRulesCore", "ForwardDiff", "SpecialFunctions"]

    [deps.LoopVectorization.extensions]
    ForwardDiffExt = ["ChainRulesCore", "ForwardDiff"]
    SpecialFunctionsExt = "SpecialFunctions"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "oneTBB_jll"]
git-tree-sha1 = "f046ccd0c6db2832a9f639e2c669c6fe867e5f4f"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2024.2.0+0"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "2fa9ee3e63fd3a4f7a9a4f4744a52f4856de82df"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.13"

[[deps.ManualMemory]]
git-tree-sha1 = "bcaef4fc7a0cfe2cba636d84cda54b5e4e4ca3cd"
uuid = "d125e4d3-2237-4719-b19c-fa641b8a4667"
version = "0.1.8"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "NetworkOptions", "Random", "Sockets"]
git-tree-sha1 = "c067a280ddc25f196b5e7df3877c6b226d390aaf"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.9"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+1"

[[deps.Measures]]
git-tree-sha1 = "c13304c81eec1ed3af7fc20e75fb6b26092a1102"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.2"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "ec4f7fbeab05d7747bdf98eb74d130a2a2ed298d"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.2.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.1.10"

[[deps.MuladdMacro]]
git-tree-sha1 = "cac9cc5499c25554cba55cd3c30543cff5ca4fab"
uuid = "46d2c3a1-f734-5fdb-9937-b9b9aeba4221"
version = "0.2.4"

[[deps.NLSolversBase]]
deps = ["DiffResults", "Distributed", "FiniteDiff", "ForwardDiff"]
git-tree-sha1 = "a0b464d183da839699f4c79e7606d9d186ec172c"
uuid = "d41bc354-129a-5804-8e4c-c37616107c6c"
version = "7.8.3"

[[deps.NLsolve]]
deps = ["Distances", "LineSearches", "LinearAlgebra", "NLSolversBase", "Printf", "Reexport"]
git-tree-sha1 = "019f12e9a1a7880459d0173c182e6a99365d7ac1"
uuid = "2774e3e8-f4cf-5e23-947b-6d7e65073b56"
version = "4.5.1"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "0877504529a3e5c3343c6f8b4c0381e57e4387e4"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.2"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.NonlinearSolve]]
deps = ["ArrayInterface", "DiffEqBase", "EnumX", "FiniteDiff", "ForwardDiff", "LinearAlgebra", "LinearSolve", "PrecompileTools", "RecursiveArrayTools", "Reexport", "SciMLBase", "SimpleNonlinearSolve", "SparseArrays", "SparseDiffTools", "StaticArraysCore", "UnPack"]
git-tree-sha1 = "e10debcea868cd6e51249e8eeaf191c25f68a640"
uuid = "8913a72c-1f9b-4ce2-8d82-65094dcecaec"
version = "1.10.1"

[[deps.OffsetArrays]]
git-tree-sha1 = "1a27764e945a152f7ca7efa04de513d473e9542e"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.14.1"
weakdeps = ["Adapt"]

    [deps.OffsetArrays.extensions]
    OffsetArraysAdaptExt = "Adapt"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "887579a3eb005446d514ab7aeac5d1d027658b8f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+1"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.23+4"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+2"

[[deps.OpenSSL]]
deps = ["BitFlags", "Dates", "MozillaCACerts_jll", "OpenSSL_jll", "Sockets"]
git-tree-sha1 = "38cb508d080d21dc1128f7fb04f20387ed4c0af4"
uuid = "4d8831e6-92b7-49fb-bdf8-b643e874388c"
version = "1.4.3"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "a028ee3cb5641cccc4c24e90c36b0a4f7707bdf5"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.0.14+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.Optim]]
deps = ["Compat", "FillArrays", "ForwardDiff", "LineSearches", "LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "PositiveFactorizations", "Printf", "SparseArrays", "StatsBase"]
git-tree-sha1 = "d9b79c4eed437421ac4285148fcadf42e0700e89"
uuid = "429524aa-4258-5aef-a3af-852621145aeb"
version = "1.9.4"

    [deps.Optim.extensions]
    OptimMOIExt = "MathOptInterface"

    [deps.Optim.weakdeps]
    MathOptInterface = "b8f27783-ece8-5eb3-8dc8-9495eed66fee"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "dfdf5519f235516220579f949664f1bf44e741c5"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.3"

[[deps.OrdinaryDiffEq]]
deps = ["ADTypes", "Adapt", "ArrayInterface", "DataStructures", "DiffEqBase", "DocStringExtensions", "ExponentialUtilities", "FastBroadcast", "FastClosures", "FiniteDiff", "ForwardDiff", "FunctionWrappersWrappers", "IfElse", "InteractiveUtils", "LineSearches", "LinearAlgebra", "LinearSolve", "Logging", "LoopVectorization", "MacroTools", "MuladdMacro", "NLsolve", "NonlinearSolve", "Polyester", "PreallocationTools", "PrecompileTools", "Preferences", "RecursiveArrayTools", "Reexport", "SciMLBase", "SciMLNLSolve", "SciMLOperators", "SimpleNonlinearSolve", "SimpleUnPack", "SparseArrays", "SparseDiffTools", "StaticArrayInterface", "StaticArrays", "TruncatedStacktraces"]
git-tree-sha1 = "f0f43037c0ba045e96f32d65858eb825a211b817"
uuid = "1dea7af3-3e70-54e6-95c3-0bf5283fa5ed"
version = "6.58.2"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.42.0+1"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "949347156c25054de2db3b166c52ac4728cbad65"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.31"

[[deps.PackageExtensionCompat]]
git-tree-sha1 = "fb28e33b8a95c4cee25ce296c817d89cc2e53518"
uuid = "65ce6f38-6b18-4e1d-a461-8949797d7930"
version = "1.0.2"
weakdeps = ["Requires", "TOML"]

[[deps.Pango_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "FriBidi_jll", "Glib_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "cb5a2ab6763464ae0f19c86c56c63d4a2b0f5bda"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.52.2+0"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "8489905bcdbcfac64d1daa51ca07c0d8f0283821"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.1"

[[deps.Pipe]]
git-tree-sha1 = "6842804e7867b115ca9de748a0cf6b364523c16d"
uuid = "b98c9c47-44ae-5843-9183-064241ee97a0"
version = "1.3.0"

[[deps.Pixman_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LLVMOpenMP_jll", "Libdl"]
git-tree-sha1 = "35621f10a7531bc8fa58f74610b1bfb70a3cfc6b"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.43.4+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.10.0"

[[deps.PlotThemes]]
deps = ["PlotUtils", "Statistics"]
git-tree-sha1 = "6e55c6841ce3411ccb3457ee52fc48cb698d6fb0"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "3.2.0"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "PrecompileTools", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "7b1a9df27f072ac4c9c7cbe5efb198489258d1f5"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.4.1"

[[deps.Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "JLFzf", "JSON", "LaTeXStrings", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "Pkg", "PlotThemes", "PlotUtils", "PrecompileTools", "Preferences", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "RelocatableFolders", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "UUIDs", "UnicodeFun", "UnitfulLatexify", "Unzip"]
git-tree-sha1 = "ccee59c6e48e6f2edf8a5b64dc817b6729f99eb5"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.39.0"

    [deps.Plots.extensions]
    FileIOExt = "FileIO"
    GeometryBasicsExt = "GeometryBasics"
    IJuliaExt = "IJulia"
    ImageInTerminalExt = "ImageInTerminal"
    UnitfulExt = "Unitful"

    [deps.Plots.weakdeps]
    FileIO = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
    GeometryBasics = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
    IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a"
    ImageInTerminal = "d8c32880-2388-543b-8c61-d9f865259254"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "ab55ee1510ad2af0ff674dbcced5e94921f867a9"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.59"

[[deps.PoissonRandom]]
deps = ["Random"]
git-tree-sha1 = "a0f1159c33f846aa77c3f30ebbc69795e5327152"
uuid = "e409e4f3-bfea-5376-8464-e040bb5c01ab"
version = "0.4.4"

[[deps.Polyester]]
deps = ["ArrayInterface", "BitTwiddlingConvenienceFunctions", "CPUSummary", "IfElse", "ManualMemory", "PolyesterWeave", "Static", "StaticArrayInterface", "StrideArraysCore", "ThreadingUtilities"]
git-tree-sha1 = "6d38fea02d983051776a856b7df75b30cf9a3c1f"
uuid = "f517fe37-dbe3-4b94-8317-1923a5111588"
version = "0.7.16"

[[deps.PolyesterWeave]]
deps = ["BitTwiddlingConvenienceFunctions", "CPUSummary", "IfElse", "Static", "ThreadingUtilities"]
git-tree-sha1 = "645bed98cd47f72f67316fd42fc47dee771aefcd"
uuid = "1d0040c9-8b98-4ee7-8388-3f51789ca0ad"
version = "0.2.2"

[[deps.PositiveFactorizations]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "17275485f373e6673f7e7f97051f703ed5b15b20"
uuid = "85a6dd25-e78a-55b7-8502-1745935b8125"
version = "0.2.4"

[[deps.PreallocationTools]]
deps = ["Adapt", "ArrayInterface", "ForwardDiff"]
git-tree-sha1 = "d7f3f63331c7c8c81245b4ee2815b7d496365833"
uuid = "d236fae5-4411-538c-8e31-a6e3d9e00b46"
version = "0.4.23"

    [deps.PreallocationTools.extensions]
    PreallocationToolsReverseDiffExt = "ReverseDiff"

    [deps.PreallocationTools.weakdeps]
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "9306f6085165d270f7e3db02af26a400d580f5c6"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.3"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.PtrArrays]]
git-tree-sha1 = "f011fbb92c4d401059b2212c05c0601b70f8b759"
uuid = "43287f4e-b6f4-7ad1-bb20-aadabca52c3d"
version = "1.2.0"

[[deps.PyCall]]
deps = ["Conda", "Dates", "Libdl", "LinearAlgebra", "MacroTools", "Serialization", "VersionParsing"]
git-tree-sha1 = "9816a3826b0ebf49ab4926e2b18842ad8b5c8f04"
uuid = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"
version = "1.96.4"

[[deps.Qt6Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Vulkan_Loader_jll", "Xorg_libSM_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_cursor_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "libinput_jll", "xkbcommon_jll"]
git-tree-sha1 = "37b7bb7aabf9a085e0044307e1717436117f2b3b"
uuid = "c0090381-4147-56d7-9ebc-da0b1113ec56"
version = "6.5.3+1"

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "e237232771fdafbae3db5c31275303e056afaa9f"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.10.1"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Random123]]
deps = ["Random", "RandomNumbers"]
git-tree-sha1 = "4743b43e5a9c4a2ede372de7061eed81795b12e7"
uuid = "74087812-796a-5b5d-8853-05524746bad3"
version = "1.7.0"

[[deps.RandomNumbers]]
deps = ["Random", "Requires"]
git-tree-sha1 = "043da614cc7e95c703498a491e2c21f58a2b8111"
uuid = "e6cf234a-135c-5ec9-84dd-332b85af5143"
version = "1.5.3"

[[deps.RecipesBase]]
deps = ["PrecompileTools"]
git-tree-sha1 = "5c3d09cc4f31f5fc6af001c250bf1278733100ff"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.4"

[[deps.RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "PrecompileTools", "RecipesBase"]
git-tree-sha1 = "45cf9fd0ca5839d06ef333c8201714e888486342"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.6.12"

[[deps.RecursiveArrayTools]]
deps = ["Adapt", "ArrayInterface", "DocStringExtensions", "GPUArraysCore", "IteratorInterfaceExtensions", "LinearAlgebra", "RecipesBase", "Requires", "StaticArraysCore", "Statistics", "SymbolicIndexingInterface", "Tables"]
git-tree-sha1 = "d7087c013e8a496ff396bae843b1e16d9a30ede8"
uuid = "731186ca-8d62-57ce-b412-fbd966d074cd"
version = "2.38.10"

    [deps.RecursiveArrayTools.extensions]
    RecursiveArrayToolsMeasurementsExt = "Measurements"
    RecursiveArrayToolsMonteCarloMeasurementsExt = "MonteCarloMeasurements"
    RecursiveArrayToolsTrackerExt = "Tracker"
    RecursiveArrayToolsZygoteExt = "Zygote"

    [deps.RecursiveArrayTools.weakdeps]
    Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
    MonteCarloMeasurements = "0987c9cc-fe09-11e8-30f0-b96dd679fdca"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"
    Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[[deps.RecursiveFactorization]]
deps = ["LinearAlgebra", "LoopVectorization", "Polyester", "PrecompileTools", "StrideArraysCore", "TriangularSolve"]
git-tree-sha1 = "6db1a75507051bc18bfa131fbc7c3f169cc4b2f6"
uuid = "f2c3362d-daeb-58d1-803e-2bc74f2840b4"
version = "0.2.23"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "ffdaf70d81cf6ff22c2b6e733c900c3321cab864"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "1.0.1"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.ResettableStacks]]
deps = ["StaticArrays"]
git-tree-sha1 = "256eeeec186fa7f26f2801732774ccf277f05db9"
uuid = "ae5879a3-cd67-5da8-be7f-38c6eb64a37b"
version = "1.1.1"

[[deps.Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "f65dcb5fa46aee0cf9ed6274ccbd597adc49aa7b"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.1"

[[deps.Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e60724fd3beea548353984dc61c943ecddb0e29a"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.4.3+0"

[[deps.RuntimeGeneratedFunctions]]
deps = ["ExprTools", "SHA", "Serialization"]
git-tree-sha1 = "04c968137612c4a5629fa531334bb81ad5680f00"
uuid = "7e49a35a-f44a-4d26-94aa-eba1b4ca6b47"
version = "0.5.13"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SIMDTypes]]
git-tree-sha1 = "330289636fb8107c5f32088d2741e9fd7a061a5c"
uuid = "94e857df-77ce-4151-89e5-788b33177be4"
version = "0.1.0"

[[deps.SLEEFPirates]]
deps = ["IfElse", "Static", "VectorizationBase"]
git-tree-sha1 = "456f610ca2fbd1c14f5fcf31c6bfadc55e7d66e0"
uuid = "476501e8-09a2-5ece-8869-fb82de89a1fa"
version = "0.6.43"

[[deps.SciMLBase]]
deps = ["ADTypes", "ArrayInterface", "ChainRulesCore", "CommonSolve", "ConstructionBase", "Distributed", "DocStringExtensions", "EnumX", "FillArrays", "FunctionWrappersWrappers", "IteratorInterfaceExtensions", "LinearAlgebra", "Logging", "Markdown", "PrecompileTools", "Preferences", "RecipesBase", "RecursiveArrayTools", "Reexport", "RuntimeGeneratedFunctions", "SciMLOperators", "StaticArraysCore", "Statistics", "SymbolicIndexingInterface", "Tables", "TruncatedStacktraces", "ZygoteRules"]
git-tree-sha1 = "916b8a94c0d61fa5f7c5295649d3746afb866aff"
uuid = "0bca4576-84f4-4d90-8ffe-ffa030f20462"
version = "1.98.1"

    [deps.SciMLBase.extensions]
    ZygoteExt = "Zygote"

    [deps.SciMLBase.weakdeps]
    Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[[deps.SciMLNLSolve]]
deps = ["DiffEqBase", "LineSearches", "NLsolve", "Reexport", "SciMLBase"]
git-tree-sha1 = "765b788339abd7d983618c09cfc0192e2b6b15fd"
uuid = "e9a6253c-8580-4d32-9898-8661bb511710"
version = "0.1.9"

[[deps.SciMLOperators]]
deps = ["ArrayInterface", "DocStringExtensions", "LinearAlgebra", "MacroTools", "Setfield", "StaticArraysCore"]
git-tree-sha1 = "23b02c588ac9a17ecb276cc62ab37f3e4fe37b32"
uuid = "c0aeaf25-5076-4817-a8d5-81caf7dfa961"
version = "0.3.9"
weakdeps = ["SparseArrays"]

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "3bac05bc7e74a75fd9cba4295cde4045d9fe2386"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.2.1"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "e2cc6d8c88613c05e1defb55170bf5ff211fbeac"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.1"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SimpleBufferStream]]
git-tree-sha1 = "874e8867b33a00e784c8a7e4b60afe9e037b74e1"
uuid = "777ac1f9-54b0-4bf8-805c-2214025038e7"
version = "1.1.0"

[[deps.SimpleNonlinearSolve]]
deps = ["ArrayInterface", "DiffEqBase", "FiniteDiff", "ForwardDiff", "LinearAlgebra", "PackageExtensionCompat", "PrecompileTools", "Reexport", "SciMLBase", "StaticArraysCore"]
git-tree-sha1 = "15ff97fa4881133caa324dacafe28b5ac47ad8a2"
uuid = "727e6d20-b764-4bd8-a329-72de5adea6c7"
version = "0.1.23"

    [deps.SimpleNonlinearSolve.extensions]
    SimpleNonlinearSolveNNlibExt = "NNlib"

    [deps.SimpleNonlinearSolve.weakdeps]
    NNlib = "872c559c-99b0-510c-b3b7-b6c96a88d5cd"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[deps.SimpleUnPack]]
git-tree-sha1 = "58e6353e72cde29b90a69527e56df1b5c3d8c437"
uuid = "ce78b400-467f-4804-87d8-8f486da07d0a"
version = "1.1.0"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "66e0a8e672a0bdfca2c3f5937efb8538b9ddc085"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.1"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.10.0"

[[deps.SparseDiffTools]]
deps = ["ADTypes", "Adapt", "ArrayInterface", "Compat", "DataStructures", "FiniteDiff", "ForwardDiff", "Graphs", "LinearAlgebra", "PackageExtensionCompat", "Random", "Reexport", "SciMLOperators", "Setfield", "SparseArrays", "StaticArrayInterface", "StaticArrays", "Tricks", "UnPack", "VertexSafeGraphs"]
git-tree-sha1 = "cce98ad7c896e52bb0eded174f02fc2a29c38477"
uuid = "47a9eef4-7e08-11e9-0b38-333d64bd3804"
version = "2.18.0"

    [deps.SparseDiffTools.extensions]
    SparseDiffToolsEnzymeExt = "Enzyme"
    SparseDiffToolsPolyesterExt = "Polyester"
    SparseDiffToolsPolyesterForwardDiffExt = "PolyesterForwardDiff"
    SparseDiffToolsSymbolicsExt = "Symbolics"
    SparseDiffToolsZygoteExt = "Zygote"

    [deps.SparseDiffTools.weakdeps]
    Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"
    Polyester = "f517fe37-dbe3-4b94-8317-1923a5111588"
    PolyesterForwardDiff = "98d1487c-24ca-40b6-b7ab-df2af84e126b"
    Symbolics = "0c5d862f-8b57-4792-8d23-62f2024744c7"
    Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[[deps.Sparspak]]
deps = ["Libdl", "LinearAlgebra", "Logging", "OffsetArrays", "Printf", "SparseArrays", "Test"]
git-tree-sha1 = "342cf4b449c299d8d1ceaf00b7a49f4fbc7940e7"
uuid = "e56a9233-b9d6-4f03-8d0f-1825330902ac"
version = "0.3.9"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "2f5d4697f21388cbe1ff299430dd169ef97d7e14"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.4.0"
weakdeps = ["ChainRulesCore"]

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

[[deps.Static]]
deps = ["IfElse"]
git-tree-sha1 = "d2fdac9ff3906e27f7a618d47b676941baa6c80c"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "0.8.10"

[[deps.StaticArrayInterface]]
deps = ["ArrayInterface", "Compat", "IfElse", "LinearAlgebra", "PrecompileTools", "Requires", "Static"]
git-tree-sha1 = "5675c74f8223ca6b5ddd2885b7b596b2235033fc"
uuid = "0d7ed370-da01-4f52-bd93-41d350b8b718"
version = "1.7.0"
weakdeps = ["OffsetArrays", "StaticArrays"]

    [deps.StaticArrayInterface.extensions]
    StaticArrayInterfaceOffsetArraysExt = "OffsetArrays"
    StaticArrayInterfaceStaticArraysExt = "StaticArrays"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "PrecompileTools", "Random", "StaticArraysCore"]
git-tree-sha1 = "eeafab08ae20c62c44c8399ccb9354a04b80db50"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.9.7"
weakdeps = ["ChainRulesCore", "Statistics"]

    [deps.StaticArrays.extensions]
    StaticArraysChainRulesCoreExt = "ChainRulesCore"
    StaticArraysStatisticsExt = "Statistics"

[[deps.StaticArraysCore]]
git-tree-sha1 = "192954ef1208c7019899fbf8049e717f92959682"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.3"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.10.0"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1ff449ad350c9c4cbc756624d6f8a8c3ef56d3ed"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.7.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "5cf7606d6cef84b543b483848d4ae08ad9832b21"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.3"

[[deps.StatsFuns]]
deps = ["HypergeometricFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "cef0472124fab0695b58ca35a77c6fb942fdab8a"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "1.3.1"

    [deps.StatsFuns.extensions]
    StatsFunsChainRulesCoreExt = "ChainRulesCore"
    StatsFunsInverseFunctionsExt = "InverseFunctions"

    [deps.StatsFuns.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.SteadyStateDiffEq]]
deps = ["DiffEqBase", "DiffEqCallbacks", "LinearAlgebra", "NLsolve", "Reexport", "SciMLBase"]
git-tree-sha1 = "2ca69f4be3294e4cd987d83d6019037d420d9fc1"
uuid = "9672c7b4-1e72-59bd-8a11-6ac3964bc41f"
version = "1.16.1"

[[deps.StochasticDiffEq]]
deps = ["Adapt", "ArrayInterface", "DataStructures", "DiffEqBase", "DiffEqNoiseProcess", "DocStringExtensions", "FillArrays", "FiniteDiff", "ForwardDiff", "JumpProcesses", "LevyArea", "LinearAlgebra", "Logging", "MuladdMacro", "NLsolve", "OrdinaryDiffEq", "Random", "RandomNumbers", "RecursiveArrayTools", "Reexport", "SciMLBase", "SciMLOperators", "SparseArrays", "SparseDiffTools", "StaticArrays", "UnPack"]
git-tree-sha1 = "b341540a647b39728b6d64eaeda82178e848f76e"
uuid = "789caeaf-c7a9-5a7d-9973-96adeb23e2a0"
version = "6.62.0"

[[deps.StrideArraysCore]]
deps = ["ArrayInterface", "CloseOpenIntervals", "IfElse", "LayoutPointers", "LinearAlgebra", "ManualMemory", "SIMDTypes", "Static", "StaticArrayInterface", "ThreadingUtilities"]
git-tree-sha1 = "f35f6ab602df8413a50c4a25ca14de821e8605fb"
uuid = "7792a7ef-975c-4747-a70f-980b88e8d1da"
version = "0.5.7"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.2.1+1"

[[deps.Sundials]]
deps = ["CEnum", "DataStructures", "DiffEqBase", "Libdl", "LinearAlgebra", "Logging", "PrecompileTools", "Reexport", "SciMLBase", "SparseArrays", "Sundials_jll"]
git-tree-sha1 = "71dc65a2d7decdde5500299c9b04309e0138d1b4"
uuid = "c3572dad-4567-51f8-b174-8c6c989267f4"
version = "4.20.1"

[[deps.Sundials_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "SuiteSparse_jll", "libblastrampoline_jll"]
git-tree-sha1 = "ba4d38faeb62de7ef47155ed321dce40a549c305"
uuid = "fb77eaff-e24c-56d4-86b1-d163f2edb164"
version = "5.2.2+0"

[[deps.SymPy]]
deps = ["CommonEq", "CommonSolve", "Latexify", "LinearAlgebra", "Markdown", "PyCall", "RecipesBase", "SpecialFunctions"]
git-tree-sha1 = "04f5a3cf4e9f451c81bcac8ea9b57bfda7f22e34"
uuid = "24249f21-da20-56a4-8eb1-6a02cf4ae2e6"
version = "1.1.14"

    [deps.SymPy.extensions]
    SymPySymbolicUtilsExt = "SymbolicUtils"

    [deps.SymPy.weakdeps]
    SymbolicUtils = "d1185830-fcd6-423d-90d6-eec64667417b"

[[deps.SymbolicIndexingInterface]]
deps = ["DocStringExtensions"]
git-tree-sha1 = "f8ab052bfcbdb9b48fad2c80c873aa0d0344dfe5"
uuid = "2efcf032-c050-4f8e-a9bb-153293bab1f5"
version = "0.2.2"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "598cd7c1f68d1e205689b1c2fe65a9f85846f297"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.12.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.ThreadingUtilities]]
deps = ["ManualMemory"]
git-tree-sha1 = "eda08f7e9818eb53661b3deb74e3159460dfbc27"
uuid = "8290d209-cae3-49c0-8002-c8c24d57dab5"
version = "0.5.2"

[[deps.TranscodingStreams]]
git-tree-sha1 = "96612ac5365777520c3c5396314c8cf7408f436a"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.1"
weakdeps = ["Random", "Test"]

    [deps.TranscodingStreams.extensions]
    TestExt = ["Test", "Random"]

[[deps.TriangularSolve]]
deps = ["CloseOpenIntervals", "IfElse", "LayoutPointers", "LinearAlgebra", "LoopVectorization", "Polyester", "Static", "VectorizationBase"]
git-tree-sha1 = "be986ad9dac14888ba338c2554dcfec6939e1393"
uuid = "d5829a12-d9aa-46ab-831f-fb7c9ab06edf"
version = "0.2.1"

[[deps.Tricks]]
git-tree-sha1 = "7822b97e99a1672bfb1b49b668a6d46d58d8cbcb"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.9"

[[deps.TruncatedStacktraces]]
deps = ["InteractiveUtils", "MacroTools", "Preferences"]
git-tree-sha1 = "ea3e54c2bdde39062abf5a9758a23735558705e1"
uuid = "781d530d-4396-4725-bb49-402e4bee1e77"
version = "1.4.0"

[[deps.URIs]]
git-tree-sha1 = "67db6cc7b3821e19ebe75791a9dd19c9b1188f2b"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.5.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.Unitful]]
deps = ["Dates", "LinearAlgebra", "Random"]
git-tree-sha1 = "d95fe458f26209c66a187b1114df96fd70839efd"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.21.0"

    [deps.Unitful.extensions]
    ConstructionBaseUnitfulExt = "ConstructionBase"
    InverseFunctionsUnitfulExt = "InverseFunctions"

    [deps.Unitful.weakdeps]
    ConstructionBase = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.UnitfulLatexify]]
deps = ["LaTeXStrings", "Latexify", "Unitful"]
git-tree-sha1 = "975c354fcd5f7e1ddcc1f1a23e6e091d99e99bc8"
uuid = "45397f5d-5981-4c77-b2b3-fc36d6e9b728"
version = "1.6.4"

[[deps.Unzip]]
git-tree-sha1 = "ca0969166a028236229f63514992fc073799bb78"
uuid = "41fe7b60-77ed-43a1-b4f0-825fd5a5650d"
version = "0.2.0"

[[deps.VectorizationBase]]
deps = ["ArrayInterface", "CPUSummary", "HostCPUFeatures", "IfElse", "LayoutPointers", "Libdl", "LinearAlgebra", "SIMDTypes", "Static", "StaticArrayInterface"]
git-tree-sha1 = "e7f5b81c65eb858bed630fe006837b935518aca5"
uuid = "3d5dd08c-fd9d-11e8-17fa-ed2836048c2f"
version = "0.21.70"

[[deps.VersionParsing]]
git-tree-sha1 = "58d6e80b4ee071f5efd07fda82cb9fbe17200868"
uuid = "81def892-9a0e-5fdd-b105-ffc91e053289"
version = "1.3.0"

[[deps.VertexSafeGraphs]]
deps = ["Graphs"]
git-tree-sha1 = "8351f8d73d7e880bfc042a8b6922684ebeafb35c"
uuid = "19fa3120-7c27-5ec5-8db8-b0b0aa330d6f"
version = "0.2.0"

[[deps.Vulkan_Loader_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Wayland_jll", "Xorg_libX11_jll", "Xorg_libXrandr_jll", "xkbcommon_jll"]
git-tree-sha1 = "2f0486047a07670caad3a81a075d2e518acc5c59"
uuid = "a44049a8-05dd-5a78-86c9-5fde0876e88c"
version = "1.3.243+0"

[[deps.Wayland_jll]]
deps = ["Artifacts", "EpollShim_jll", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "7558e29847e99bc3f04d6569e82d0f5c54460703"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.21.0+1"

[[deps.Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "93f43ab61b16ddfb2fd3bb13b3ce241cafb0e6c9"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.31.0+0"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Zlib_jll"]
git-tree-sha1 = "d9717ce3518dc68a99e6b96300813760d887a01d"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.13.1+0"

[[deps.XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "a54ee957f4c86b526460a720dbc882fa5edcbefc"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.41+0"

[[deps.XZ_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "ac88fb95ae6447c8dda6a5503f3bafd496ae8632"
uuid = "ffd25f8a-64ca-5728-b0f7-c24cf3aae800"
version = "5.4.6+0"

[[deps.Xorg_libICE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "326b4fea307b0b39892b3e85fa451692eda8d46c"
uuid = "f67eecfb-183a-506d-b269-f58e52b52d7c"
version = "1.1.1+0"

[[deps.Xorg_libSM_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libICE_jll"]
git-tree-sha1 = "3796722887072218eabafb494a13c963209754ce"
uuid = "c834827a-8449-5923-a945-d239c165b7dd"
version = "1.2.4+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "afead5aba5aa507ad5a3bf01f58f82c8d1403495"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.8.6+0"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6035850dcc70518ca32f012e46015b9beeda49d8"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.11+0"

[[deps.Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "34d526d318358a859d7de23da945578e8e8727b7"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.4+0"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "d2d1a5c49fae4ba39983f63de6afcbea47194e85"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.6+0"

[[deps.Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[deps.Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[deps.Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[deps.Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "47e45cd78224c53109495b3e324df0c37bb61fbe"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.11+0"

[[deps.Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8fdda4c692503d44d04a0603d9ac0982054635f9"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.1+0"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "bcd466676fef0878338c61e655629fa7bbc69d8e"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.17.0+0"

[[deps.Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "730eeca102434283c50ccf7d1ecdadf521a765a4"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.2+0"

[[deps.Xorg_xcb_util_cursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_jll", "Xorg_xcb_util_renderutil_jll"]
git-tree-sha1 = "04341cb870f29dcd5e39055f895c39d016e18ccd"
uuid = "e920d4aa-a673-5f3a-b3d7-f755a4d47c43"
version = "0.1.4+0"

[[deps.Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[deps.Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[deps.Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "330f955bc41bb8f5270a369c473fc4a5a4e4d3cb"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.6+0"

[[deps.Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "691634e5453ad362044e2ad653e79f3ee3bb98c3"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.39.0+0"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e92a1a012a10506618f10b7047e478403a046c77"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.5.0+0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e678132f07ddb5bfa46857f0d7620fb9be675d3b"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.6+0"

[[deps.ZygoteRules]]
deps = ["ChainRulesCore", "MacroTools"]
git-tree-sha1 = "27798139afc0a2afa7b1824c206d5e87ea587a00"
uuid = "700de1a5-db45-46bc-99cf-38207098b444"
version = "0.2.5"

[[deps.eudev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "gperf_jll"]
git-tree-sha1 = "431b678a28ebb559d224c0b6b6d01afce87c51ba"
uuid = "35ca27e7-8b34-5b7f-bca9-bdc33f59eb06"
version = "3.2.9+0"

[[deps.fzf_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "a68c9655fbe6dfcab3d972808f1aafec151ce3f8"
uuid = "214eeab7-80f7-51ab-84ad-2988db7cef09"
version = "0.43.0+0"

[[deps.gperf_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3516a5630f741c9eecb3720b1ec9d8edc3ecc033"
uuid = "1a1c6b14-54f6-533d-8383-74cd7377aa70"
version = "3.1.1+0"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1827acba325fdcdf1d2647fc8d5301dd9ba43a9d"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.9.0+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+1"

[[deps.libdecor_jll]]
deps = ["Artifacts", "Dbus_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pango_jll", "Wayland_jll", "xkbcommon_jll"]
git-tree-sha1 = "9bf7903af251d2050b467f76bdbe57ce541f7f4f"
uuid = "1183f4f0-6f2a-5f1a-908b-139f9cdfea6f"
version = "0.2.2+0"

[[deps.libevdev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "141fe65dc3efabb0b1d5ba74e91f6ad26f84cc22"
uuid = "2db6ffa8-e38f-5e21-84af-90c45d0032cc"
version = "1.11.0+0"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[deps.libinput_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "eudev_jll", "libevdev_jll", "mtdev_jll"]
git-tree-sha1 = "ad50e5b90f222cfe78aa3d5183a20a12de1322ce"
uuid = "36db933b-70db-51c0-b978-0f229ee0e533"
version = "1.18.0+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "d7015d2e18a5fd9a4f47de711837e980519781a4"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.43+1"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "490376214c4721cdaca654041f635213c6165cb3"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+2"

[[deps.mtdev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "814e154bdb7be91d78b6802843f76b6ece642f11"
uuid = "009596ad-96f7-51b1-9f1b-5ce2d5e8a71e"
version = "1.1.6+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.52.0+1"

[[deps.oneTBB_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7d0ea0f4895ef2f5cb83645fa689e52cb55cf493"
uuid = "1317d2d5-d96f-522e-a858-c73665f53c3e"
version = "2021.12.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"

[[deps.xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "9c304562909ab2bab0262639bd4f444d7bc2be37"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "1.4.1+1"
"""

# ╔═╡ Cell order:
# ╟─cc5fa8b8-4da3-11ee-28fd-7dacab544db3
# ╟─aabae4cb-3912-408d-bacf-267f2440c047
# ╟─9db0e27f-32f5-4b03-9d70-5dea9f079ecb
# ╟─ba749db8-c015-4137-ac7e-92fc0bfbe7ce
# ╟─a25d1d5d-abc8-4ec4-80b2-ecdaea755a1c
# ╠═be1a604c-6cf6-405f-9fa0-86e3b454315e
# ╟─759f6f53-866c-4cc8-9bb5-41be3b43f1dc
# ╠═bdc5a009-c6c4-434d-a619-63081c6af32d
# ╠═f4c5f8dd-a66f-4b1a-8a6f-3e4ad9615999
# ╟─b8fe4424-9eac-4011-85ba-f1bf5e72c718
# ╟─1b1dbf06-c67b-4447-9049-4ab1bf82ee8a
# ╠═cf63fd31-4c00-46e5-8648-713b59080eba
# ╟─451a1910-4ce9-4e15-bca3-c516e20e5bd5
# ╠═c42f51a3-a02d-4c86-beee-7feedd378ad0
# ╠═538e7d53-5cc3-4447-b1c7-3d02a0946f09
# ╟─6369c1ac-e52c-4d81-869d-77cbd483fd8b
# ╟─03a0fc10-9875-4248-8711-8a3887db30a5
# ╟─8aa24500-d236-4e24-bf06-4db94e612a50
# ╠═54a7e106-4537-4857-a9e7-fdc3e9bf4ba1
# ╠═f0ecf625-53f3-4595-8764-ab0a95c5b6e3
# ╟─17c3d4a5-048a-44c1-a5f0-5278a2322f60
# ╠═25b351fa-69e6-482e-9543-12e1dde9e438
# ╠═1163c920-d2ca-42e7-9b9e-1e19d494bb46
# ╠═43c38357-4d59-457d-9b90-94ae1f267212
# ╟─7d030c04-ac3b-4832-a3e8-6053fc9c14e7
# ╟─1ae8b353-df38-430f-b220-401adddac1d1
# ╠═f85d4b96-e5d8-4d5c-aaed-df30c8c06084
# ╟─0c6f2477-1252-4485-9596-2748a2508e14
# ╠═77c08e89-b5ca-45d3-8916-3ac8cf9453cb
# ╟─6647a86f-7f6d-43d7-892e-724d3a191ca9
# ╠═b40aefaa-4600-42f7-ab1d-d92b54fb6401
# ╟─a20f135e-f061-4287-9e11-3ffad5cc64b8
# ╠═177d0f02-9045-49d5-84cd-bc7b6ebb58fc
# ╟─2a2f1d95-60d1-41b5-9d94-e69e7c5bba78
# ╟─9e35dc47-ff08-4254-96dd-fe27c0c7366d
# ╠═6e2bc9b4-6b61-49c8-ae72-0bc94e72543a
# ╟─bbbb2744-a2d9-412a-9938-e0a97aa2620b
# ╟─fed350c9-aaa1-4a1a-9338-7f244b5e738b
# ╟─f4a47b15-3c2c-4f08-b611-08d57971b04f
# ╟─3fba7ef0-a994-4f7e-934a-cb475ceea441
# ╠═9c1588f1-b49d-470e-b71c-9e70bebafc25
# ╟─5fe29e57-fe90-4ae8-9beb-3662c51d9c16
# ╟─537f07ab-f141-4a38-9dcd-be8de62fc3e5
# ╟─0a42d713-ecc8-41cb-90f0-30f3c598c1af
# ╟─4267d65e-1cfd-4fc1-ba61-3f15ba5885c6
# ╟─06007dd6-94dc-4ed6-bf53-18a44db17c06
# ╟─6fc7e520-e85e-4b96-ae6a-1d1312e9e6c8
# ╟─e2698160-39e6-4a76-ac17-6ccd56fb151f
# ╟─2ae4f6e6-a1f0-4618-b0a2-ca3e4c73ee7f
# ╟─d3780235-46e6-472c-9f46-18ac5cf8ee40
# ╟─945aba6b-ad67-44e7-ae6b-50cff0ac014a
# ╟─57d40abd-2a35-468a-9334-f63d962ba604
# ╟─0d40bd72-6be9-4127-9c63-6041473a3ccc
# ╟─b9f569a7-3854-40c8-8e64-de13f5eb19cf
# ╟─4af334c0-c8bd-416f-956e-6c702a6b5f01
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
