# Factor-driven two-regime regression
# An empirical example for testing linearity based on Hansen (1996, Econometrica)
# Estimation results in Section 9.1
#
# Last Update
#   2018-09-07 by Simon Lee  
#   2018-10-06

rm(list=ls())

library('lmtest')
library('sandwich')
source('lib_fadtwo.R')



# ------------------------------------------------------------------------------------
# 
# Set the environment variables
#
#-------------------------------------------------------------------------------------

# Data selection
selection_data = 'hansen' # 'hansen' or 'potter'


# Model selection
selection_method = 'no-selection' # 'l0' or 'no-selection'

# Estimation algorithm
method = 'joint' # 'joint' or 'iter'

# Number of additional factors
no_factors = 'L5' # 'L5' or 'all'

# Maximum iterations if method is 'iter'
K.bar = 2

# Tuning parameters for grid search
grid.type = 'random' # 'fixed' or 'random'
zeta = 0.5
grid.size = 10^4

# eta: the size of effective zero
eta = 1e-6

# Gurobi options: 
params <- list(OutputFlag=1, FeasibilityTol=1e-9, MIPGap=1e-4, TimeLimit=Inf)   
# OutputFlag: print out outputs
# FeasibilityTol: error allowance for the inequality constraints
# MIPGap: Stop if the gap is smaller than this bound. Default is 1e-4
# TimeLimit: Stop if the computation time reaches this bound. Default is infinity


# Minimum and maximum bounds for the propotion of each regime
tau1 = 0.15
tau2 = 0.85

# Number of lags in the regressor part
n.lags=5                                    

# Number of bootstrap replications

n_bootstrap <- 500

# Specifiying the seed
set.seed(45462)
# ------------------------------------------------------------------------------------
# 
# End of setting the environment variables
#
#-------------------------------------------------------------------------------------


# Read Data
if (selection_data == 'hansen'){
      gnp <- read.table("../data/gnp.dat")  # 47:01-90:03 (Potter's data includes obs. for 90:04 but Hansen's data excludes it)
     lgnp <- log(gnp[,1])
       yg <- (lgnp[2:175]-lgnp[1:174])*400 # Annual GNP growth in percentage 47:02-90:03
       yg <- ts(yg, start=c(1947,2), end=c(1990,3), frequency=4)
    n.obs <- length(yg)
}
if (selection_data == 'potter'){
  gnp <- read.table("../data/potter.dat")  # 47:01-90:04 (Potter's data includes obs. for 90:04 but Hansen's data excludes it)
  lgnp <- log(gnp[,2])
  yg <- (lgnp[2:176]-lgnp[1:175])*400 # Annual GNP growth in percentage 47:02-90:03
  yg <- ts(yg, start=c(1947,2), end=c(1990,4), frequency=4)
  n.obs <- length(yg)
}

# dependent variable 
y = yg[-(1:n.lags)]     
dat.year <- time(y)  
# regressors
x = cbind(1, yg[(n.lags):(n.obs-1)],  yg[(n.lags-1):(n.obs-2)], yg[1:(n.obs-n.lags)])
colnames(x) = c('.const','.L1.y','.L2.y','.L5.y')
# Number of observations
n = nrow(x)
# Number of covariates, dim(x)
d.x = ncol(x)
#-----------------------------------------------------------------------------------------------------------------------------
#
# Choose factors. 
#
#-----------------------------------------------------------------------------------------------------------------------------

if (no_factors == 'all'){
f = cbind(x[,3], x[,2], x[,4], -1)
}
if (no_factors == 'L5'){
f = cbind(x[,3], x[,4], -1)
}
if (no_factors == 'no'){
f = cbind(x[,3], -1)
}

# Number of factors, dim(f)
d.f = ncol(f)

# Decomposition of factors 
f1=as.matrix(f[,1])
if ((d.f > 2) && (selection_method == 'l0')){
f2=as.matrix(f[,(2:(d.f-1))])
p = ncol(f2)  
}

# Run threshold regression with state = 1(L2.y >= 0.0125721)
    state.hansen = (f1 > 0.0125721)
        x.hansen = cbind(x*as.numeric(1-state.hansen), x*as.numeric(state.hansen))
      reg.hansen = lm(y~x.hansen-1)     
 sigmahat.hansen = mean((y-fitted.values(reg.hansen))^2)
inference.hansen = coeftest(reg.hansen, vcov = vcovHC(reg.hansen, type = "HC3"))

output_text_file_name <- paste("../results/app1-section-9-1.txt", sep = "")
sink(file = output_text_file_name, append = FALSE)
options(digits=3)

cat("-------------------------------------------------------------------------------------\n")
cat("Equation (9.1) \n")
cat("Estimation results using L2.y as the threshold variable (Hansen, 1996) \n \n")
cat("Coefficients are shown for two states (f1 < 0.0125721) and (f1 > 0.0125721), respectively \n \n")
print.table(round(inference.hansen,2))
cat("------------------------------------------------------------------------------------- \n \n")

sink()    

#-----------------------------------------------------------------------------------------------------------------------------
#
# Choose the size of the parameter sets
#
#-----------------------------------------------------------------------------------------------------------------------------

Bnd.Const = 20
 L.bt = rep(-Bnd.Const,d.x)
 U.bt = rep(Bnd.Const,d.x)

 L.dt = rep(-Bnd.Const,d.x)
 U.dt = rep(Bnd.Const,d.x)
 

 L.gm = c(1,rep(-Bnd.Const,d.f-1))
 U.gm = c(1,rep(Bnd.Const,d.f-1)) 

 
 
 
 if ((d.f > 2) && (selection_method == 'l0')){
L.gm1 = c(1)
U.gm1 = c(1)

L.gm2 = c(rep(-Bnd.Const,p))
U.gm2 = c(rep(Bnd.Const,p))

L.gm3 = -Bnd.Const
U.gm3 = Bnd.Const

L.p = 0
U.p = p
}
ld = sigmahat.hansen*log(n.obs)/n.obs     #BIC

time.start = proc.time()[3]



# Joint Estimation Algorithm
if (method == 'joint') {

if (selection_method == 'l0'){
    est.out=fadtwo_selection(y=y,x=x,f1=f1,f2=f2,method='joint',L.bt=L.bt,U.bt=U.bt,L.dt=L.dt,U.dt=U.dt,L.gm1=L.gm1,U.gm1=U.gm1,L.gm2=L.gm2,U.gm2=U.gm2,L.gm3=L.gm3,U.gm3=U.gm3,L.p=L.p, U.p=U.p, tau1=tau1,tau2=tau2, eta=eta,params=params,ld=ld)  
}
else {est.out=fadtwo(y=y,x=x,f=f,method='joint',L.bt=L.bt,U.bt=U.bt,L.dt=L.dt,U.dt=U.dt,L.gm=L.gm,U.gm=U.gm,tau1=tau1,tau2=tau2)
}    
}
  
# Iterative Estimation Algorithm
if (method == 'iter'){

  # Generate the grid points

if (grid.type == 'fixed'){   

  grid=gen_grid(option.grid='fixed', width=c(1,rep(zeta,d.f-1)), n.total=NULL, L.grid=c(L.gm1,rep(-Bnd.Const,d.f-1)), U.grid=c(U.gm1,rep(Bnd.Const,d.f-1)))
} else {
  grid=gen_grid(option.grid='random', width=NULL, n.total=grid.size, L.grid=c(L.gm1,rep(-Bnd.Const,d.f-1)), U.grid=c(U.gm1,rep(Bnd.Const,d.f-1)))
}  
  if (selection_method == 'l0'){
  est.out=fadtwo_selection(y=y,x=x,f1=f1,f2=f2,method='iter',L.gm1=L.gm1,U.gm1=U.gm1,L.gm2=L.gm2,U.gm2=U.gm2,L.gm3=L.gm3,U.gm3=U.gm3,L.p=L.p,U.p=U.p,tau1=tau1,tau2=tau2,eta=eta,params=params,grid=grid,max.iter=K.bar,ld=ld)
  }
  else {
  est.out=fadtwo(y=y,x=x,f=f,method='iter',L.gm=L.gm,U.gm=U.gm,tau1=tau1,tau2=tau2,grid=grid,max.iter=K.bar)
}
}


#-----------------------------------------------------------------------------------------------------------
#
# Post-estimation analysis
#
#----------------------------------------------------------------------------------------------------------
# Save the esitmates
bt.hat = est.out$bt.hat
dt.hat = est.out$dt.hat
gm.hat = est.out$gm.hat
objval = est.out$objval

# Run threshold regression with the estimated state
    state.est = (f %*% gm.hat >= eta*.99)
        x.est = cbind(x*as.numeric(1-state.est), x*as.numeric(state.est))
      reg.est = lm(y~x.est-1)
    resid.est = y-fitted.values(reg.est)
 sigmahat.est = mean(resid.est^2)
inference.est = coeftest(reg.est, vcov = vcovHC(reg.est, type = "HC3"))

sink(file = output_text_file_name, append = TRUE)
options(digits=3)


cat("------------------------------------------------------------------------------------- \n")
cat("Estimation results with a vector of possible factors \n")
cat("Coefficients are shown for two states (f %*% gm.hat > 0) and (f %*% gm.hat < 0), respectively \n")
print.table(round(inference.est,2))

cat("sigmahat (Hansen) -- sigmahat (Est.) \n")
print(c(sigmahat.hansen, sigmahat.est))
cat("------------------------------------------------------------------------------------- \n \n")

sink()  

#-----------------------------------------------------------------------------------------------------------
#
# Testing Linearity 
#
#----------------------------------------------------------------------------------------------------------

# Constrained Estimation  

reg.constrained = lm(y~x-1)
constrained = mean((residuals(reg.constrained))^2)    
test.statistic = n*(constrained - sigmahat.est)/sigmahat.est  

### Bootstrap ###         

results_bootstrap <- matrix(0, nrow = n_bootstrap, ncol = 1)         

for (bb in 1:n_bootstrap){      
  
  bm_norm <- rnorm(n, mean = 0, sd = 1)
  
  y_star <- x%*%bt.hat + bm_norm*resid.est
  
  # Joint Estimation Algorithm
  if (method == 'joint') {
    
    b.est.out=fadtwo(y=y_star,x=x,f=f,method='joint',L.bt=L.bt,U.bt=U.bt,L.dt=L.dt,U.dt=U.dt,L.gm=L.gm,U.gm=U.gm,tau1=tau1,tau2=tau2)
    
  }  
  
  # Iterative Estimation Algorithm
  if (method == 'iter'){
    
    b.est.out=fadtwo(y=y_star,x=x,f=f,method='iter',L.gm=L.gm,U.gm=U.gm,tau1=tau1,tau2=tau2,grid=grid,max.iter=K.bar)
    
  }
  
  # Save the estimates
  
  gm.b = b.est.out$gm.hat
  state.b = (f %*% gm.b >= eta*.99)
  x.b = cbind(x*as.numeric(1-state.b), x*as.numeric(state.b))
  reg.b = lm(y_star~x.b-1)
  unconstrained.b = mean((y_star-fitted.values(reg.b))^2)  
  
  
  # Constrained Estimation  
  
  reg.constrained.b = lm(y_star~x-1)
  constrained.b = mean((y_star-fitted.values(reg.constrained.b))^2)    
  test.statistic.b = n*(constrained.b - unconstrained.b)/unconstrained.b  
  
  results_bootstrap[bb,1] <- test.statistic.b
  
}


p.value <- mean(test.statistic < results_bootstrap)


sink(file = output_text_file_name, append = TRUE)
options(digits=4)

cat("------------------------------------------------------------------------------------- \n")
cat("Testing Linearity \n")
cat("number of bootstrap replications = ", n_bootstrap, "\n")
cat("Constrained -- Unconstrained     =", constrained, "--", sigmahat.est, "\n")
cat("Test Statistic                   =", test.statistic, "\n")
cat("p-value                          = ",p.value, "\n")
cat("------------------------------------------------------------------------------------- \n \n")

time.end = proc.time()[3]
runtime = time.end - time.start
cat('Runtime     =', runtime, 'sec','\n')  
sink()  

save.image(file="..\results\app1-section-9-1.RData")
