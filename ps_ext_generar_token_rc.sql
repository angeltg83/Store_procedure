CREATE PROCEDURE [dbo].[ps_ext_generar_token_rc]
	@identificacion VARCHAR(20),
	@tipoc INT,
	@p_codigo INT = 0 OUT,
	@p_datos VARCHAR(MAX) = '' OUT,
	@p_mensaje VARCHAR(2000) = '' OUT
AS
BEGIN
	SET nocount ON
	
	DECLARE @json VARCHAR(MAX), @token VARCHAR(6), @codeHTML varchar(max), @destinatarios varchar(5000), @tiempo INT
	DECLARE @l_codigo INT, @l_mensaje VARCHAR(2000), @l_datos VARCHAR(MAX)
	
	DECLARE @persona AS TABLE (
		identificacion VARCHAR(20),
		nombre_completo VARCHAR(250),
		email VARCHAR(1000)
	)
	
	BEGIN TRY
		IF @identificacion IS NULL OR LTRIM(RTRIM(@identificacion)) = '' BEGIN 
			RAISERROR('La identificación no puede estar vacia.', 11, 1)
		END
		
		IF @tipoc = 0 BEGIN 
			RAISERROR('El tipo de identificación no puede estar vacio.', 11, 1)
		END
		
		SET @tiempo = 180
		
		INSERT INTO @persona(identificacion, nombre_completo, email)
		SELECT p.identificacion,
			   ISNULL(p.nombre_completo, CONCAT(p.apellido_paterno, ' ', p.apellido_materno, ' ', p.primer_nombre, ' ', p.segundo_nombre)) AS nombre_completo,
			   (SELECT TOP 1 detalle 
				  FROM dbco.persona_contacto AS pc 
				 WHERE pc.id_persona = p.id_persona 
				   AND pc.id_tipo_contacto = 3 
				 ORDER BY pc.fecha_ingreso DESC) AS email
		  FROM dbco.persona p
		 WHERE p.identificacion = @identificacion
		 
		SET @token = dbo.fn_custom_pass(6, 'CN')
		
		SET @codeHTML = '<h3>Su código se seguridad es: '+  @token +' </h3>'
		SET @destinatarios = (SELECT email FROM @persona)
	
		EXEC msdb.dbo.sp_send_dbmail @recipients = @destinatarios,
									 @copy_recipients = 'luiggi.rivera@bitekso.com',
									 @subject = 'CÓDIGO DE SEGURIDAD',
									 @body = @codeHTML,
									 @body_format = 'HTML'
		 
		SET @json = (SELECT identificacion, nombre_completo, dbo.fx_mascara_email(email, 3, 'XXXXXXXXXX', 3) email, @tiempo tiempo 
					   FROM @persona FOR JSON PATH)
					   
		EXEC seguridad_sistemas.dbo.ps_ingresar_token @identificacion, @token, @tiempo, @l_codigo OUT, @l_datos OUT, @l_mensaje OUT
		IF @l_codigo != 200 BEGIN
			RAISERROR(@l_mensaje, 11, 1)
		END
		
		SET @p_codigo = 200
		SET @p_datos = JSON_QUERY(@json, '$[0]')
	END TRY
	BEGIN CATCH
		DECLARE    @ERROR_NUMBER  int = ERROR_NUMBER()
	    DECLARE    @ERROR_STATE  nvarchar(10) = ERROR_STATE()
	    DECLARE    @ERROR_SEVERITY  nvarchar(10) = ERROR_SEVERITY()
	    DECLARE    @ERROR_PROCEDURE  nvarchar(100) = ERROR_PROCEDURE()
	    DECLARE    @ERROR_LINE  int = ERROR_LINE()
	    DECLARE    @ERROR_MESSAGE  nvarchar(200) = ERROR_MESSAGE()
	    
	    EXEC       ps_log_error @ERROR_NUMBER, 
	    						@ERROR_STATE, 
	    						@ERROR_SEVERITY, 
	    						@ERROR_PROCEDURE, 
	    						@ERROR_LINE, 
	    						@ERROR_MESSAGE,
	    		   				@p_codigo = @p_codigo output,
	    		   				@p_mensaje = @p_mensaje output,
	    		   				@p_datos = @p_datos output
	END CATCH
END
