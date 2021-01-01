%---------------------------------------------------------------------%
%
%This code computes the CONVERGENCE relations for 1D Advection Equation using the 
%CG and DG methods with 3rd Order RK.
%This version constructs the Global Matrices which are good for 
%comparing CG and DG.
%Written by F.X. Giraldo on July 3, 2012
%           Department of Applied Mathematics
%           Naval Postgraduate School
%           Monterey, CA 93943-5216
%Modified by M.A. Kopera on November 13, 2020
%           Department of Mathematics
%           Boise State University
%           Boise, ID 83725
%---------------------------------------------------------------------%
clear all; 
close all;

%Input Data
%nelem=3; %Number of Elements == 22
%nop1=2;
%nop2=2;    %Interpolation Order == 5

nop_array = [2,4,6,8];
nelem_array = [20,40,80,160];

kstages=3; %RK2, RK3, RK34
dt=1e-2; %time-step, fraction of one revolution
Courant_max=0.05;
time_final=0.025; %final time in revolutions
nplots=50; %plotting variable - Ignore
iplot_solution=0; %Switch to Plot or Not.
interpolation_points=1; %=1 for LGL; =2 equi-spaced points; =3 for LG
integration_points=1; %=1 for LGL and =2 for LG
integration_type=2; %=1 is inexact and =2 is exact
space_method_type='cg'; %=1 for CG and =2 for DG

icase=1; %case number: 1 is a Gaussian, 2 is a square wave, 3 is
         %Gaussian with source and 4 is square wave with source.
         
%stabilization - won't need it for now         
xmu=0.0; %filtering strength: 1 is full strength and 0 is no filter
ifilter=1000000; %time-step frequency that the filter is applied.
diss=0;
visc=0.000;%for CG N=4 and N=5
nlaplacian=0;

if (nlaplacian == 0) 
    visc=0;
end

%Store Constants
% ngl=nop + 1;
ntime=time_final/dt;

for i_nop=1:length(nop_array)
    nop = nop_array(i_nop)
    ngl=nop+1;
    
    for i_nelem = 1:length(nelem_array)
        nelem = nelem_array(i_nelem)
        method_text = [space_method_type];
        if space_method_type == 'cg'
            npoin=nop*nelem + 1;
        elseif space_method_type == 'dg'
            npoin=ngl*nelem;
        end
        npoin_array(i_nop,i_nelem) = npoin;
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
        dt=Courant_max*dx/u;
        ntime=round(time_final/dt);
        dt=time_final/ntime;
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
           if (mod(itime,ifilter) == 0)
              rhs = apply_filter_dg(qp,f,nelem,ngl);
              qp=rhs;
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
        l2_norm(i_nop,i_nelem)=sqrt( top/bot );
        % npoin
        % nelem
        % ngl
        % nq

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

        end

    end %for nelem
end %for nop

l2_norm
%Plot Error
figure;
LegendsStrings = cell(length(nop_array),1);
loglog(npoin_array(1,:),l2_norm(1,:),'-o','LineWidth',2,'MarkerSize',10)
c = polyfit(log10(npoin_array(1,:)),log10(l2_norm(1,:)),1);
LegendsStrings{1} = ['nop = ',num2str(nop_array(1)),' rate = ',sprintf('%.2f',c(1))]; 

fprintf("Convergence: nop = %d rate: %f\n",nop_array(1),c(1));
hold on
for i=2:length(nop_array)
    loglog(npoin_array(i,:),l2_norm(i,:),'-o','LineWidth',2,'MarkerSize',10)  
    c = polyfit(log10(npoin_array(i,:)),log10(l2_norm(i,:)),1);
    LegendsStrings{i} = ['nop = ',num2str(nop_array(i)),' rate = ',sprintf('%.2f',c(1))];
    fprintf("Convergence: nop = %d rate: %f\n",nop_array(i),c(1));
end
hold off
legend(LegendsStrings, 'Interpreter', 'none')
xlabel('npoin'); ylabel('L2 error');
grid on
title(['Convergence plot of the ',space_method_type,' method'])