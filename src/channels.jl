abstract type Conductance end
abstract type IonChannel <: Conductance end
abstract type Synapse <: Conductance end

"""
return unparameterised type as symbol
"""
function get_name(ch::Conductance) 
    Base.typename(ch |> typeof) |> Symbol
end

"""
fallback option for channels without a calcium current
"""
calcium_current(ch::IonChannel, sys::ODESystem) = Num(0)
voltage_hook(V, ch::IonChannel, sys::ODESystem) = V ~ sys.V 
calcium_hook(Ca, ch::IonChannel, sys::ODESystem) = Ca ~ sys.Ca
#################### Channels ###############################


#################### NaV ###############################
mutable struct NaV{S,T} <: IonChannel
    ḡNa::S
    mNa::T
    hNa::T
    ENa::T
end

NaV(x) = NaV(x, 0.,0., 50.)
NaV(x,y) = NaV(x, 0.,0., y)


m∞(::NaV, V) =  1.0/(1.0+exp((V+25.5)/-5.29))
h∞(::NaV, V) =  1.0/(1.0+exp((V+48.9)/5.18))
τm(::NaV, V) =  1.32 - 1.26/(1+exp((V+120.0)/-25.0))
τh(::NaV, V) =  (0.67/(1.0+exp((V+62.9)/-10.0)))*(1.5+1.0/(1.0+exp((V+34.9)/3.6)))
ionic_current(::NaV, sys::ODESystem) = sys.INa


function channel_dynamics(ch::NaV, V, Ca, D, t)    
    states = @variables mNa(t) hNa(t) INa(t)
    parameters = @parameters ḡNa ENa 
    eqs = [ D(mNa) ~       (1/τm(ch, V))*(m∞(ch, V) - mNa), 
            D(hNa) ~       (1/τh(ch, V))*(h∞(ch, V) - hNa),
            INa ~ ḡNa*mNa^3*hNa*(ENa - V)]   
    current = [eqs[3]]
    defaultmap = [mNa => ch.mNa, hNa => ch.hNa, ḡNa => ch.ḡNa, ENa => ch.ENa]
    return eqs, states, parameters, current, defaultmap
end  


#################### Slow calcium current #############################
mutable struct CaS{S,T} <: IonChannel
    ḡCaS::S
    τCa::S
    mCaS::T
    hCaS::T
end

CaS(x,y) = CaS(x,y, 0.,0.)
CaS(x) = CaS(x,20., 0., 0.)

m∞(::CaS, V) = 1.0/(1.0+exp((V+33.0)/-8.1))
h∞(::CaS, V) = 1.0/(1.0+exp((V+60.0)/6.2))
τm(::CaS, V) = 1.4 + 7.0/(exp((V+27.0)/10.0) + exp((V+70.0)/-13.0));
τh(::CaS, V) = 60.0 + 150.0/(exp((V+55.0)/9.0) + exp((V+65.0)/-16.0));
ionic_current(::CaS, sys::ODESystem) = sys.ICaS
calcium_current(::CaS, sys::ODESystem) = sys.ICaS
ECa(::CaS, Ca) = (500.0)*(8.6174e-5)*(283.15)*(log(max((3000.0/Ca), 0.001)))
# ECa(::CaS, Ca) = 30.

function channel_dynamics(ch::CaS, V, Ca, D, t)
    states = @variables mCaS(t) hCaS(t) ICaS(t) ICaS_Ca(t)
    parameters = @parameters ḡCaS τCa
    eqs = [ D(mCaS) ~       (1/τm(ch, V))*(m∞(ch, V) - mCaS), 
            D(hCaS) ~       (1/τh(ch, V))*(h∞(ch, V) - hCaS),
            ICaS ~ ḡCaS*mCaS^3*hCaS*(ECa(ch, Ca) - V),
            ICaS_Ca ~ (1. / τCa)* (0.025 + 0.94ICaS - 0.5Ca)
            ]
    current = eqs[3:4]
    defaultmap = [mCaS => ch.mCaS, hCaS => ch.hCaS, ḡCaS => ch.ḡCaS, τCa => ch.τCa]
    return eqs, states, parameters, current, defaultmap
end

#################### Transient calcium current ######################

mutable struct CaT{S,T} <: IonChannel
    ḡCaT::S
    τCa::S
    mCaT::T
    hCaT::T
end
CaT(x,y) = CaT(x,y,0.,0.)
CaT(x) = CaT(x, 20., 0., 0.)
m∞(::CaT, V) = 1.0/(1.0 + exp((V+27.1)/-7.2))
h∞(::CaT, V) = 1.0/(1.0 + exp((V+32.1)/5.5))
τm(::CaT, V) = 21.7 - 21.3/(1.0 + exp((V+68.1)/-20.5));
τh(::CaT, V) = 105.0 - 89.8/(1.0 + exp((V+55.0)/-16.9));


ionic_current(::CaT, sys::ODESystem) = sys.ICaT
calcium_current(::CaT, sys::ODESystem) = sys.ICaT
ECa(::CaT, Ca) = (500.0)*(8.6174e-5)*(283.15)*(log(max((3000.0/Ca), 0.001)))

function channel_dynamics(ch::CaT, V, Ca, D, t)
    states = @variables mCaT(t) hCaT(t) ICaT(t) ICaT_Ca(t)
    parameters = @parameters ḡCaT τCa
    eqs = [ D(mCaT) ~       (1/τm(ch, V))*(m∞(ch, V) - mCaT), 
            D(hCaT) ~       (1/τh(ch, V))*(h∞(ch, V) - hCaT),
            ICaT ~ ḡCaT*mCaT^3*hCaT*(ECa(ch, Ca) - V),
            ICaT_Ca ~ (1. / τCa)* (0.025 + 0.94ICaT - 0.5Ca)
            ]
    current = eqs[3:4]
    defaultmap = [mCaT => ch.mCaT, hCaT => ch.hCaT, ḡCaT => ch.ḡCaT, τCa => ch.τCa]
    return eqs, states, parameters, current, defaultmap
end

####################  #########################
"""
A-type potassium current
"""
mutable struct Ka{S,T} <: IonChannel
    ḡKa::S
    mKa::T
    hKa::T
    EK::T
end
Ka(x,y) = Ka(x,0., 0.,y)
Ka(x) = Ka(x,0.,0.,-80.)

m∞(::Ka, V) = 1.0/(1.0+exp((V+27.2)/-8.7))
h∞(::Ka, V) = 1.0/(1.0+exp((V+56.9)/4.9))
τm(::Ka, V) = 11.6 - 10.4/(1.0+exp((V+32.9)/-15.2));
τh(::Ka, V) = 38.6 - 29.2/(1.0+exp((V+38.9)/-26.5));
ionic_current(::Ka, sys::ODESystem) = sys.IKa

function channel_dynamics(ch::Ka, V, Ca, D, t)    
    states = @variables mKa(t) hKa(t) IKa(t)
    parameters = @parameters ḡKa EK 
    eqs = [ D(mKa) ~       (1/τm(ch, V))*(m∞(ch, V) - mKa), 
            D(hKa) ~       (1/τh(ch, V))*(h∞(ch, V) - hKa),
            IKa ~ ḡKa*mKa^3*hKa*(EK - V)]   
    current = [eqs[3]]
    defaultmap = [mKa => ch.mKa, hKa => ch.hKa, ḡKa => ch.ḡKa, EK => ch.EK]
    return eqs, states, parameters, current, defaultmap
end  

################### Calcium-activated potassium current ########

mutable struct KCa{S,T} <: IonChannel
    ḡKCa::S
    mKCa::T
    EK::T
end

KCa(x,y) = KCa(x,0.,y)
KCa(x) = KCa(x,0., -80.)
m∞(::KCa, V, Ca) = (Ca/(Ca+3.0))/(1.0+exp((V+28.3)/-12.6));
τm(::KCa, V) = 90.3 - 75.1/(1.0+exp((V+46.0)/-22.7));
ionic_current(::KCa, sys::ODESystem) = sys.IKCa

function channel_dynamics(ch::KCa, V, Ca, D, t)    
    states = @variables mKCa(t) IKCa(t)
    parameters = @parameters ḡKCa EK 
    eqs = [ D(mKCa) ~       (1/τm(ch, V))*(m∞(ch, V, Ca) - mKCa), 
            IKCa ~ (ḡKCa*mKCa^4)*(EK - V)]   
    current = [eqs[2]]
    defaultmap = [mKCa => ch.mKCa, ḡKCa => ch.ḡKCa, EK => ch.EK]
    return eqs, states, parameters, current, defaultmap
end  



"""
    Delayed rectifier potassium current
"""
mutable struct Kdr{S,T} <: IonChannel
    ḡKdr::S
    mKdr::T
    EK::T
end
Kdr(x) = Kdr(x,0., -80.)
Kdr(x,y) = Kdr(x,0.,y)
m∞(::Kdr, V)=  1.0/(1.0+exp((V+12.3)/-11.8));
τm(::Kdr, V)=  7.2 - 6.4/(1.0+exp((V+28.3)/-19.2));
ionic_current(::Kdr, sys::ODESystem) = sys.IKdr

function channel_dynamics(ch::Kdr, V, Ca, D, t)    
    states = @variables mKdr(t) IKdr(t)
    parameters = @parameters ḡKdr EK 
    eqs = [ D(mKdr) ~       (1/τm(ch, V))*(m∞(ch, V) - mKdr), 
            IKdr ~ (ḡKdr*mKdr^4)*(EK - V)]   
    current = [eqs[2]]
    defaultmap = [mKdr => ch.mKdr, ḡKdr => ch.ḡKdr, EK => ch.EK]
    return eqs, states, parameters, current, defaultmap
end  

"""
H current
"""
mutable struct H{S,T} <: IonChannel
    ḡH::S
    mH::T
    EH::T
end

H(x) = H(x, 0., -20.)
H(x,y) = H(x,0.,y)

m∞(::H, V) = 1.0/(1.0+exp((V+70.0)/6.0))
τm(::H, V) = (272.0 + 1499.0/(1.0+exp((V+42.2)/-8.73)))
ionic_current(::H, sys::ODESystem) = sys.IH

function channel_dynamics(ch::H, V, Ca, D, t)    
    states = @variables mH(t) IH(t)
    parameters = @parameters ḡH EH 
    eqs = [ D(mH) ~       (1/τm(ch, V))*(m∞(ch, V) - mH), 
            IH ~ ḡH*mH*(EH - V)]   
    current = [eqs[2]]
    defaultmap = [mH => ch.mH, ḡH => ch.ḡH, EH => ch.EH]
    return eqs, states, parameters, current, defaultmap
end  


"""
leak current
"""
mutable struct Leak{S} <: IonChannel
    ḡLeak::S 
    ELeak::S
end
Leak(x) = Leak(x, -50.)
ionic_current(::Leak, sys::ODESystem) = sys.ILeak

function channel_dynamics(ch::Leak, V, Ca, D, t)    
    states = @variables ILeak(t)
    parameters = @parameters ḡLeak ELeak 
    eqs = [ILeak ~ ḡLeak*(ELeak - V)]   
    current = [eqs[1]]
    defaultmap = [ḡLeak => ch.ḡLeak, ELeak => ch.ELeak]
    return eqs, states, parameters, current, defaultmap
end  
