%---------------------------------------------------------------------%
%
%Comes from PROJECT 2: BEST_CG_DG_NODAL_GLOBAL_MATRICES_DISPERSION_VISC
%Used in ECMWF Paper and in Giraldo EBG Text
%
%This code computes the DISPERSION relations for 1D Advection Equation using the 
%CG and DG methods with 3rd Order RK.
%This version constructs the Global Matrices which are good for 
%comparing CG and DG.
%Written by F.X. Giraldo on July 3, 2012
%           Department of Applied Mathematics
%           Naval Postgraduate School
%           Monterey, CA 93943-5216
%--------------------------------------------------------------------%
clear all; 
close all;

%Input Data
nelem=10; %Number of Elements == 22
nop1=1;
nop2=5;    %Interpolation Order == 5

kstages=4; %RK2, RK3, RK34
dt=1e-4; %time-step, fraction of one revolution
Courant_max=0.001;
time_final=0.025; %final time in revolutions
nplots=50; %plotting variable - Ignore
iplot_solution=0; %Switch to Plot Solution or Not.
iplot_convergence = 1;
iplot_evalues=0; %Switch to Plot Eigenvalues
iplot_matrices=0; %Switch to Plot Matrices
interpolation_points=1; %=1 for LGL; =2 equi-spaced points; =3 for LG
integration_points=1; %=1 for LGL and =2 for LG
integration_type=2; %=1 is inexact and =2 is exact
space_method_type='dg'; %=1 for CG and =2 for DG

icase=1; %case number: 1 is a Gaussian, 2 is a square wave, 3 is
         %Gaussian with source and 4 is square wave with source.
xmu=0.05; %filtering strength: 1 is full strength and 0 is no filter
ifilter=0; %time-step frequency that the filter is applied.
diss=0;
visc=1e-5; %for CG N=4 and N=5 visc=1e-5;
nlaplacian=1;

if (nlaplacian == 0) 
    visc=0;
end

%Store Constants
% ngl=nop + 1;
ntime=time_final/dt;

dt0 = dt;
nop_array = (3:6);
N_array = [20, 40 , 60, 80];
error_array = zeros(length(N_array),length(nop_array));
npoin_array = zeros(length(N_array),length(nop_array));

for i_N = 1:length(N_array)
for i_nop = 1:length(nop_array)
    nop=nop_array(i_nop);
    nelem = N_array(i_N)
    nop
    ngl=nop+1;
    
    method_text = [space_method_type];
    if space_method_type == 'cg'
        npoin=nop*nelem + 1;
    elseif space_method_type == 'dg'
        npoin=ngl*nelem;
    end
    
npoin_array(i_N,i_nop) = npoin;  

%Compute Interpolation and Integration Points
if (interpolation_points == 1)
    [xgl,wgl]=legendre_gauss_lobatto(ngl);
    method_text=[method_text '_Interp=LGL'];
elseif (interpolation_points == 2)
     wgl=1;
     xgl=linspace(-1,1,ngl);
     method_text=[method_text '_Interp=ESP'];
elseif (interpolation_points == 3)
     [xgl,wgl]=legendre_gauss(ngl);
     method_text=[method_text '_Interp=LG'];
end
if (integration_points == 1)
    integration_text=['LGL'];
    if (integration_type == 1)
        noq=nop;
    elseif (integration_type == 2)
        noq=nop+1;
    end
    nq=noq + 1;
    [xnq,wnq]=legendre_gauss_lobatto(nq);
elseif (integration_points == 2)
    integration_text=['LG'];
    noq=nop;
    nq=noq + 1;
    [xnq,wnq]=legendre_gauss(nq);
end
method_text=[method_text '_Integr=' integration_text];
main_text=[method_text ': ' integration_text];

%Compute Lagrange Polynomial and derivatives
[psi,dpsi] = lagrange_basis3(ngl,nq,xgl,xnq);
   
%Compute Filter Matrix
f = filter_init(ngl,xgl,xmu);

%Create Grid
[coord,intma]=create_grid_dg(ngl,nelem,xgl);
dx=coord(2,1)-coord(1,1);
u=2;
dt=Courant_max*dx/u
ntime=round(time_final/dt);
dt=time_final/ntime;

%something from python code



Courant=u*dt/dx;

%Compute Exact Solution
time=0;
qe = exact_solution_dg(coord,nelem,ngl,time,icase);
fe = source_function_dg(coord,nelem,ngl,time,icase);

%Create Local/Element Mass and Differentiation Matrices
mass = create_mass_dg(coord,nelem,ngl,nq,wnq,psi);
diff_matrix = create_diff_matrix_dg(ngl,nq,wnq,psi,dpsi);
laplacian_matrix = create_Lmatrix_dg(coord,nelem,ngl,nq,wnq,dpsi);

%Form Global Matrix and Periodic BC Pointers
inode=zeros(ngl,nelem);
iperiodic=zeros(npoin,1);
if space_method_type == 'cg'
    inode=intma;
    for i=1:npoin
       iperiodic(i)=i;
    end
    iperiodic(npoin)=iperiodic(1);
elseif space_method_type == 'dg'
    ip=0;
    for e=1:nelem
        for i=1:ngl
            ip=ip+1;
            inode(i,e)=ip;
        end
    end
    for i=1:npoin
        iperiodic(i)=i;
    end
end

%Form Global Mass and Differentiation Matrices
Mmatrix=zeros(npoin,npoin);
Dmatrix=zeros(npoin,npoin);
Fmatrix=zeros(npoin,npoin);
Lmatrix=zeros(npoin,npoin);
for e=1:nelem
    for i=1:ngl
        ip=iperiodic(inode(i,e));
        for j=1:ngl
            jp=iperiodic(inode(j,e));
            Mmatrix(ip,jp)=Mmatrix(ip,jp) + mass(i,j,e);
            Dmatrix(ip,jp)=Dmatrix(ip,jp) + u*diff_matrix(i,j);
            Lmatrix(ip,jp)=Lmatrix(ip,jp) + laplacian_matrix(i,j,e);
        end
    end
end
if space_method_type == 'cg'
    Mmatrix(npoin,npoin)=1;
elseif space_method_type == 'dg'
    Fmatrix = create_Fmatrix_dg(inode,npoin,nelem,ngl,u,diss);
end
Lmatrix_hat=Mmatrix\Lmatrix;

%Construct Full RHS matrix
if (nlaplacian > 0)
    HV_matrix=eye(npoin);
elseif (nlaplacian == 0)
    HV_matrix=zeros(npoin);
end
for i=1:nlaplacian
    HV_matrix=Lmatrix_hat*HV_matrix;
end
Rmatrix=Mmatrix\(Dmatrix - Fmatrix) ;

%Left-Multiply by Inverse Mass Matrix
Dmatrix_hat=Rmatrix - visc*HV_matrix;
    
%Form Long Exact Solution Vector
qexact=zeros(1,npoin);
for e=1:nelem
    for i=1:ngl
        ip=inode(i,e);
        qexact(ip)=qe(i,e);
    end
end

%Initialize State Vector
qexact=qexact';
q1=qexact;
q0=qexact;
qp=qexact;
iplot=round(ntime/nplots);

%Time Integration
for itime=1:ntime
   time=time + dt;
   
   %disp(['itime =  ',num2str(itime),' time = ', num2str(time),' courant = ', num2str(Courant)]);
   for ik=1:kstages
      switch kstages
          case 2  %RK2
              switch ik
                 case 1
                    a0=1;
                    a1=0;
                    beta=1;
                 case (2)
                    a0=0.5;
                    a1=0.5;
                    beta=0.5;
              end %ik
          case 3 %RK3
              switch ik
                  case 1
                     a0=1;
                     a1=0;
                     beta=1;
                  case (2)
                     a0=3.0/4.0;
                     a1=1.0/4.0;
                     beta=1.0/4.0;
                  case (3)
                     a0=1.0/3.0;
                     a1=2.0/3.0;
                     beta=2.0/3.0;
              end %ik
          case 4 %RK34
               switch ik
                   case 1
                    a0=1;
                    a1=0;
                    beta=1.0/2.0;
                   case (2)
                    a0=0;
                    a1=1;
                    beta=1.0/2.0;
                   case (3)
                    a0=2.0/3.0;
                    a1=1.0/3.0;
                    beta=1.0/6.0;
                   case (4)
                    a0=0;
                    a1=1;
                    beta=1.0/2.0;
               end %ik
      end %kstages
      dtt=dt*beta;
      qp=a0*q0 + a1*q1 + dtt*Dmatrix_hat*qp;
      
      %apply Periodic bc
      if space_method_type == 'cg'
        qp(npoin)=qp(iperiodic(npoin)); 
      end
      
      %Update
      q1=qp;
   end %ik
   
   %Filter Solution
   if (ifilter > 0)
       if (mod(itime,ifilter) == 0)
           disp(size(qp))
          rhs = apply_filter_dg(qp,f,nelem,ngl);
          qp=rhs;
       end
   end
   
   %Update Q
   q0=qp;
end %itime

%Compute Exact Solution
qe = exact_solution_dg(coord,nelem,ngl,time,icase);
%Form Long Exact Solution Vector
for e=1:nelem
    for i=1:ngl
        ip=inode(i,e);
        qexact(ip)=qe(i,e);
    end
end
%Compute Norm
top=0;
bot=0;
error=zeros(npoin,1);
for i=1:npoin
   top=top + (q0(i)-qexact(i))^2;
   error(i)=(q0(i)-qexact(i));
   bot=bot + qexact(i)^2;
end %i
l2_norm=sqrt( top/bot )
% npoin
% nelem
% ngl
% nq
i_N
error_array(i_N,i_nop) = l2_norm;

%Compute a gridpoint solution
x_sol=zeros(npoin,1);
for ie=1:nelem
   for i=1:ngl
      ip=inode(i,ie);
      x_sol(ip)=coord(i,ie);
   end 
end
 
%Plot Solution
if (iplot_solution == 1)
    h=figure;
    figure(h);
    plot_handle=plot(x_sol,q0,'r-');
    set(plot_handle,'LineWidth',2);
    hold on
    plot_handle=plot(x_sol,qexact,'b--');
    set(plot_handle,'LineWidth',2);

    xlabel('x','FontSize',18);
    ylabel('q(x,t)','FontSize',18);

    title_text=[main_text ': Ne = ' num2str(nelem) ', N = ' num2str(nop) ', Q = ' num2str(noq) ', L2 Norm = ' num2str(l2_norm) ', T = ' num2str(time)];
    title([title_text],'FontSize',18);
    set(gca, 'FontSize', 18);
    
    %Plot Error
%     figure;
%     plot_handle=plot(x_sol,error,'r-');
%     set(plot_handle,'LineWidth',2);
% 
%     xlabel('x','FontSize',18);
%     ylabel('Error','FontSize',18);
% 
%     if (diss == 0)
%        file_ps=[method_text num2str(nelem) 'p' num2str(nop)];
%         legend(method_text,'Exact');	
%     elseif (diss == 1)
%        file_ps=[method_text num2str(nelem) 'p' num2str(nop)];
%        legend(method_text,'Exact');	
%     end
% 
%     title_text=[main_text ': Ne = ' num2str(nelem) ', N = ' num2str(nop) ', Q = ' num2str(noq) ', L2 Norm = ' num2str(l2_norm) ', T = ' num2str(time)];
%     title([title_text],'FontSize',18);
%     set(gca, 'FontSize', 18);
end

%Plot E-values
if (iplot_matrices == 1)

    %Plot E-values
    figure
    if space_method_type == 'cg'
        nn=npoin-1;
    elseif space_method_type == 'dg'
        nn=npoin;    
    end
    D=Dmatrix_hat(1:nn,1:nn);
    [V,E]=eig(D);
    [m,n]=size(E);
    lambda=diag(E);
    
    if (iplot_evalues == 1)
        xmin=min(real(lambda));xmax=max(real(lambda));
        ymin=min(imag(lambda));ymax=max(imag(lambda));
        xlam=real(lambda)/ymax;
        ylam=imag(lambda)/ymax;
        plot_handle=plot(xlam,ylam,'ro');
        title_text=[main_text ': E-values with max(Re) = ', num2str(max(real(lambda))) ];
        title([title_text],'FontSize',18);
        set(plot_handle,'LineWidth',2);
        xlabel('Re','FontSize',18);
        ylabel('Im','FontSize',18);
%         hold on;
%         yy=linspace(-1,1,10);
%         xx=linspace(0,0,10);
%         plot(xx,yy,'--k');
        xmin=min(xmin,-1);
        xmax=max(xmax,+1);
%         axis([-1 +1 -1 +1]);
        set(gca, 'FontSize', 18);
    end

    %file_ps=['DG_n' num2str(nelem) 'p' num2str(nop) 'q' num2str(noq) 'diss' num2str(diss) '_Evalues'];
    %eval(['print ' file_ps ' -depsc']);
    
    D=-Dmatrix_hat(1:nn,1:nn); 
    [V,E]=eig(D);
    m=length(E);
    lambda=diag(E);
    for i=1:m
         [maxvalue,k]=max( abs( fftshift( fft( V(:,i) ) ) ) );%determines the wavenumber associated 
                                                                 %with the maximum frequency.
%         [maxvalue,k]=max( abs( ( fft( V(:,i) ) ) ) );
%         [maxvalue,k]=max( fft( V(:,i) ) );
%            V_FFT(i,:)=abs((fft( V(:,i) )));
%            figure
%            plot(real(V_FFT(i,:)),imag(V_FFT(i,:)),'ro');
%            title_text=[' i = ',num2str(i)];
%            title([title_text],'FontSize',18);

        if mod(m,2) == 0 %even
            k=k - m/2 -1;
        else
            k=k - (m+1)/2; %odd
%             k=k - m/2 -1;
        end
        
%          k=k - round(m/2);
        wavenumber(i)=k;
        W=V(:,i);
%         W=fftshift(real(V(:,i)));

%         if (iplot_evalues == 1) 
%             figure
%             plot(real(W),'r-','LineWidth',2);
%             hold on
%             plot(imag(W),'b--','LineWidth',2);
%             title_text=[' Evalue = ',num2str(imag(lambda(i))),' Evector i = ', num2str(i),' Mode = ',num2str(k) ];
%             title([title_text],'FontSize',18);
%             legend('Real','Imaginary');
%         end
    end
    
    %Normalize Wave Number
    figure
    kmax=max(abs(wavenumber));
    wavenumber=abs(wavenumber)/kmax;
%     kmax=max(wavenumber);
%     wavenumber=wavenumber/kmax;
    wavenumber(nn)=1;
    
    %Normalize Eigenvalue
    c=1/(2*pi*kmax);
    lambda=c*lambda;
    amplification=exp(-real(lambda));
    plot(wavenumber,imag(lambda),'ro','LineWidth',2);
    wn_max=max(imag(lambda));
    wn_max=max(wn_max,1);
    hold on;
    plot(wavenumber,amplification,'b+','LineWidth',2);
    lambda_max=max(imag(lambda));
    xx=linspace(-1,1,10);
    plot(xx,xx,'k-','LineWidth',2);
%     title_text=[method_text, ': Dispersion for N = ',num2str(nop),' N_E = ',num2str(nelem)];
%     title([title_text],'FontSize',18);
    xlabel('k/k_{max}','FontSize',18);
    ylabel('\omega/\omega_{analytic}','FontSize',18);
    set(gca, 'FontSize', 18);
    wmax=max(imag(lambda));
    ampmax=max(amplification);
    ymax=max(wmax,ampmax);
    wmin=min(imag(lambda));
    axis([0 +1 0 ymax]);
    legend('Dispersion','Dissipation');
    %Define File Name
    if ( strcmp(space_method_type,'cg'))
        file_ps=[method_text '_ne=' num2str(nelem) '_nop=' num2str(nop) '_noq=' num2str(noq) '_visc=' num2str(visc) '.eps']
    elseif (strcmp(space_method_type,'dg'))
        file_ps=[method_text '_ne=' num2str(nelem) '_nop=' num2str(nop) '_noq=' num2str(noq) '_diss=' num2str(diss) '.eps']
    end
%     title_text=[file_ps];
%     title([title_text],'FontSize',18);
    eval(['print ' file_ps ' -depsc']);
end %plot matrices
end %for nop
end %for N

if(iplot_convergence)
    loglog(N_array,error_array(:,1),'-o')
    grid on
    hold on


    for i_nop = 2:length(nop_array)
        %loglog(npoin_array(:,i_nop),error_array(:,i_nop),'-o')
        loglog(N_array,error_array(:,i_nop),'-o')
    end
    hold off
    legendCell = cellstr(num2str(nop_array', 'nop=%-d'));
    legend(legendCell)
end




