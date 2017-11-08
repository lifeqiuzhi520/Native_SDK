/*!*********************************************************************************************************************
\File         OGLESHelloAPI_OSX.mm
\Title        OpenGL ES 2.0 HelloAPI Tutorial
\Author       PowerVR by Imagination, Developer Technology Team
\Copyright    Copyright (c) Imagination Technologies Limited.
\brief  Basic Tutorial that shows step-by-step how to initialize OpenGL ES 2.0, use it for drawing a triangle and terminate it.
              Entry Point: main
***********************************************************************************************************************/
#define DYNAMICGLES_NO_NAMESPACE
#define DYNAMICEGL_NO_NAMESPACE
#include <DynamicGles.h>

#import <AppKit/NSApplication.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSScreen.h>
#import <AppKit/NSView.h>
#include <vector>

// Index to bind the attributes to vertex shaders
unsigned int VertexArray(0);
unsigned int Kfps (120.0);

// Width and Height of the window
unsigned int Width  (800);
unsigned int Height (600);


/*!*********************************************************************************************************************
 Class AppController
 ***********************************************************************************************************************/
@class AppController;

@interface AppController : NSObject <NSApplicationDelegate>
{
@private
	NSTimer*         m_timer;		// timer for rendering our OpenGL content
	NSWindow*        m_window;   	// Our window
	NSView*          m_view;        // Our view
    
    // Shaders
    GLuint           m_fragShader;
    GLuint           m_vertexShader;
    GLuint           _program;
    
    // Vertex buffer objects
    GLuint           m_vertexBuffer;
    
    // EGL variables
    EGLDisplay       m_Display;
    EGLSurface       m_Surface;
    EGLContext       m_Context;
}
@end

@implementation AppController

/*!*********************************************************************************************************************
\param[in]		 functionLastCalled   Function which triggered the error
\return		 True if no GL error was detected
\brief Tests for an GL error and prints it in a message box.
***********************************************************************************************************************/
- (BOOL) testGLError:(const char *)functionLastCalled
{
	// glGetError returns the last error that occurred using OpenGL ES, not necessarily the status of the last called function. The user
	// has to check after every single OpenGL ES call or at least once every frame. Usually this would be for debugging only, but for this
	// example it is enabled always
	GLenum lastError = glGetError();
	if (lastError != GL_NO_ERROR)
	{
		NSLog(@"%s failed (%x).\n", functionLastCalled, lastError);
		return FALSE;
	}
	return TRUE;
}

/*!*********************************************************************************************************************
\param[in]			functionLastCalled          Function which triggered the error
\return		True if no EGL error was detected
\brief	Tests for an EGL error and prints it.
 ***********************************************************************************************************************/
- (BOOL) testEGLError:(const char *)functionLastCalled
{
	// eglGetError returns the last error that occurred using EGL, not necessarily the status of the last called function. The user has to
	// check after every single EGL call or at least once every frame. Usually this would be for debugging only, but for this example
	// it is enabled always.
	EGLint lastError = eglGetError();
	if (lastError != EGL_SUCCESS)
	{
		NSLog(@"%s failed (%x).\n", functionLastCalled, lastError);
		return FALSE;
	}
	return TRUE;
}

/*!*********************************************************************************************************************
\param[out]		eglDisplay				    EGLDisplay created
\return		Whether the function succeeded or not.
\brief	Creates an EGLDisplay and initializes it.
 ***********************************************************************************************************************/
- (BOOL) createEGLDisplay:(EGLDisplay &)eglDisplay
{
	// Get an EGL display.
	// EGL uses the concept of a "display" which in most environments corresponds to a single physical screen. After creating a native
	// display for a given windowing system, EGL can use this handle to get a corresponding EGLDisplay handle to it for use in rendering.
	// Should this fail, EGL is usually able to provide access to a default display. For Null window systems, there is no display so NULL
	// is passed the this function.
	eglDisplay = eglGetDisplay((EGLNativeDisplayType)0);
	if (eglDisplay == EGL_NO_DISPLAY)
	{
		printf("Failed to get an EGLDisplay");
		return FALSE;
	}

	// Initialize EGL.
	// EGL has to be initialized with the display obtained in the previous step. All EGL functions other than eglGetDisplay
	// and eglGetError need an initialized EGLDisplay.
	// If an application is not interested in the EGL version number it can just pass NULL for the second and third parameters, but they
	// are queried here for illustration purposes.
	EGLint eglMajorVersion, eglMinorVersion;
	if (!eglInitialize(eglDisplay, &eglMajorVersion, &eglMinorVersion))
	{
		printf("Failed to initialize the EGLDisplay");
		return FALSE;
	}
	return TRUE;
}

/*!*********************************************************************************************************************
\param[out]		eglConfig                   The EGLConfig chosen by the function
\param[in]			eglDisplay                  The EGLDisplay used by the application
\return		Whether the function succeeded or not.
\brief	Chooses an appropriate EGLConfig and return it.
***********************************************************************************************************************/
- (BOOL) chooseEGLConfig:(EGLConfig &)eglConfig fromDisplay:(EGLDisplay)eglDisplay
{
	// Specify the required configuration attributes.
	// An EGL "configuration" describes the capabilities an application requires and the type of surfaces that can be used for drawing.
	// Each implementation exposes a number of different configurations, and an application needs to describe to EGL what capabilities it
	// requires so that an appropriate one can be chosen. The first step in doing this is to create an attribute list, which is an array
	// of key/value pairs which describe particular capabilities requested. In this application nothing special is required so we can query
	// the minimum of needing it to render to a window, and being OpenGL ES 2.0 capable.
	const EGLint configurationAttributes[] =
	{
		EGL_SURFACE_TYPE,		EGL_WINDOW_BIT,
		EGL_RENDERABLE_TYPE,	EGL_OPENGL_ES2_BIT,
		EGL_NONE
	};

	// Find a suitable EGLConfig
	// eglChooseConfig is provided by EGL to provide an easy way to select an appropriate configuration. It takes in the capabilities
	// specified in the attribute list, and returns a list of available configurations that match or exceed the capabilities requested.
	// Details of all the possible attributes and how they are selected for by this function are available in the EGL reference pages here:
	// http://www.khronos.org/registry/egl/sdk/docs/man/xhtml/eglChooseConfig.html
	// It is also possible to simply get the entire list of configurations and use a custom algorithm to choose a suitable one, as many
	// advanced applications choose to do. For this application however, taking the first EGLConfig that the function returns suits
	// its needs perfectly, so we limit it to returning a single EGLConfig.
	EGLint configsReturned;
	if (!eglChooseConfig(eglDisplay, configurationAttributes, &eglConfig, 1, &configsReturned) || (configsReturned != 1))
	{
		printf("Failed to choose a suitable config.");
		return FALSE;
	}
	return TRUE;
}

/*!*********************************************************************************************************************
\param[out]		eglSurface					The EGLSurface created
\param[in]			eglDisplay                  The EGLDisplay used by the application
\param[in]			eglConfig                   An EGLConfig chosen by the application
\param[in]         view                        The NSView to render to
\return		Whether the function succeeds or not.
\brief	Creates an EGLSurface for the screen
***********************************************************************************************************************/
- (BOOL) createEGLSurface:(EGLSurface &)eglSurface fromDisplay:(EGLDisplay)eglDisplay withConfig:(EGLConfig)eglConfig
				 withView:(NSView *)view
{
	//	Create an EGLSurface for rendering.
	// Using a native window created earlier and a suitable eglConfig, a surface is created that can be used to render OpenGL ES calls to.
	// There are three main surface types in EGL, which can all be used in the same way once created but work slightly differently:
	// - Window Surfaces  - These are created from a native window and are drawn to the screen.
	// - Pixmap Surfaces  - These are created from a native windowing system as well, but are offscreen and are not displayed to the user.
	// - PBuffer Surfaces - These are created directly within EGL, and like Pixmap Surfaces are offscreen and thus not displayed.
	// The offscreen surfaces are useful for non-rendering contexts and in certain other scenarios, but for most applications the main
	// surface used will be a window surface as performed below. For NULL window systems, there are no actual windows, so NULL is passed
	// to this function.
	eglSurface = eglCreateWindowSurface(eglDisplay, eglConfig, (EGLNativeWindowType)view, NULL);
	if (![self testEGLError:"eglCreateWindowSurface"]){	return FALSE; }
	return TRUE;
}

/*!*********************************************************************************************************************
\param[out]		eglContext                  The EGLContext created by this function
\param[in]			eglDisplay                  The EGLDisplay used by the application
\param[in]			eglConfig                   An EGLConfig chosen by the application
\param[in]			eglSurface					The EGLSurface created by the application
\return		Whether the function succeeds or not.
\brief	Sets up the EGLContext, creating it and then installing it to the current thread.
***********************************************************************************************************************/
- (BOOL) setupEGLContext:(EGLContext &)eglContext fromDisplay:(EGLDisplay)eglDisplay withConfig:(EGLConfig)eglConfig
			 withSurface:(EGLSurface)eglSurface
{
	// Make OpenGL ES the current API.
	// EGL needs a way to know that any subsequent EGL calls are going to be affecting OpenGL ES,
	// rather than any other API (such as OpenVG).
	eglBindAPI(EGL_OPENGL_ES_API);
	if (![self testEGLError:"eglBindAPI"]){	return FALSE; }

	// Create a context.
	// EGL has to create what is known as a context for OpenGL ES. The concept of a context is OpenGL ES's way of encapsulating any
	// resources and state. What appear to be "global" functions in OpenGL actually only operate on the current context. A context
	// is required for any operations in OpenGL ES.
	// Similar to an EGLConfig, a context takes in a list of attributes specifying some of its capabilities. However in most cases this
	// is limited to just requiring the version of the OpenGL ES context required - In this case, OpenGL ES 2.0.
	EGLint contextAttributes[] =
	{
		EGL_CONTEXT_CLIENT_VERSION, 2,
		EGL_NONE
	};

	// Create the context with the context attributes supplied
	eglContext = eglCreateContext(eglDisplay, eglConfig, NULL, contextAttributes);
	if (![self testEGLError:"eglCreateContext"]){	return FALSE;	}

	// Bind the context to the current thread.
	// Due to the way OpenGL uses global functions, contexts need to be made current so that any function call can operate on the correct
	// context. Specifically, make current will bind the context to the thread it's called from, and unbind it from any others. To use
	// multiple contexts at the same time, users should use multiple threads and synchronise between them.
	eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext);
	if (![self testEGLError:"eglMakeCurrent"]){	return FALSE; }
	return TRUE;
}

/*!*********************************************************************************************************************
\param[out]		vertexBuffer                Handle to a vertex buffer object
\return		Whether the function succeeds or not.
\brief	Initializes shaders, buffers and other state required to begin rendering with OpenGL ES
***********************************************************************************************************************/
- (BOOL) initializeBuffer:(GLuint &)vertexBuffer
{
	// Concept: Vertices
	// When rendering a polygon or model to screen, OpenGL ES has to be told where to draw the object, and more fundamentally what shape
	// it is. The data used to do this is referred to as vertices, points in 3D space which are usually collected into groups of three
	// to render as triangles. Fundamentally, any advanced 3D shape in OpenGL ES is constructed from a series of these vertices - each
	// vertex representing one corner of a polygon.

	// Concept: Buffer Objects
	// To operate on any data, OpenGL first needs to be able to access it. The GPU maintains a separate pool of memory it uses independent
	// of the CPU. Whilst on many embedded systems these are in the same physical memory, the distinction exists so that they can use and
	// allocate memory without having to worry about synchronising with any other processors in the device.
	// To this end, data needs to be uploaded into buffers, which are essentially a reserved bit of memory for the GPU to use. By creating
	// a buffer and giving it some data we can tell the GPU how to render a triangle.

	// Vertex data containing the positions of each point of the triangle
	GLfloat vertexData[] = {
                            -0.4f,-0.4f, 0.0f,  // Bottom Left
		                     0.4f,-0.4f, 0.0f,  // Bottom Right
		                     0.0f, 0.4f, 0.0f
                           }; // Top Middle

	// Generate a buffer object
	glGenBuffers(1, &vertexBuffer);

	// Bind buffer as an vertex buffer so we can fill it with data
	glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);

	//	Set the buffer's size, data and usage
	// Note the last argument - GL_STATIC_DRAW. This tells the driver that we intend to read from the buffer on the GPU, and don't intend
	// to modify the data until we're done with it.
	glBufferData(GL_ARRAY_BUFFER, sizeof(vertexData), vertexData, GL_STATIC_DRAW);
	if (![self testGLError:"glBufferData"]){return FALSE;}
	return TRUE;
}

/*!*********************************************************************************************************************
\param[out]		fragmentShader              Handle to a fragment shader
\param[out]		vertexShader                Handle to a vertex shader
\param[out]		shaderProgram               Handle to a shader program containing the fragment and vertex shader
\return		Whether the function succeeds or not.
\brief	Initializes shaders, buffers and other state required to begin rendering with OpenGL ES
***********************************************************************************************************************/
-(BOOL) initializeFragmentShader:(GLuint &)fragmentShader andVertexShader:(GLuint &)vertexShader withProgram:(GLuint &)shaderProgram
{
	// Concept: Shaders
	// OpenGL ES 2.0 uses what are known as shaders to determine how to draw objects on the screen. Instead of the fixed function
	// pipeline in early OpenGL or OpenGL ES 1.x, users can now programmatically define how vertices are transformed on screen, what
	// data is used where, and how each pixel on the screen is colored.
	// These shaders are written in GL Shading Language ES: http://www.khronos.org/registry/gles/specs/2.0/GLSL_ES_Specification_1.0.17.pdf
	// which is usually abbreviated to simply "GLSL ES".
	// Each shader is compiled on-device and then linked into a shader program, which combines a vertex and fragment shader into a form
	// that the OpenGL ES implementation can execute.

	// Concept: Fragment Shaders
	// In a final buffer of image data, each individual point is referred to as a pixel. Fragment shaders are the part of the pipeline
	// which determine how these final pixels are colored when drawn to the framebuffer. When data is passed through here, the positions
	// of these pixels is already set, all that's left to do is set the final color based on any defined inputs.
	// The reason these are called "fragment" shaders instead of "pixel" shaders is due to a small technical difference between the two
	// concepts. When you color a fragment, it may not be the final color which ends up on screen. This is particularly true when
	// performing blending, where multiple fragments can contribute to the final pixel color.
	const char* const fragmentShaderSource = "\
	void main (void)\
	{\
	gl_FragColor = vec4(1.0, 1.0, 0.66 ,1.0);\
	}";

	// Create a fragment shader object
	fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);

	// Load the source code into it
	glShaderSource(fragmentShader, 1, (const char**)&fragmentShaderSource, NULL);

	// Compile the source code
	glCompileShader(fragmentShader);

	// Check that the shader compiled
	GLint isShaderCompiled;
	glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &isShaderCompiled);
	if (!isShaderCompiled)
	{
		// If an error happened, first retrieve the length of the log message
		int infoLogLength, charactersWritten;
		glGetShaderiv(fragmentShader, GL_INFO_LOG_LENGTH, &infoLogLength);

		// Allocate enough space for the message and retrieve it
		std::vector<char> infoLog; infoLog.resize(infoLogLength);
		glGetShaderInfoLog(fragmentShader, infoLogLength, &charactersWritten, infoLog.data());

		// Display the error in a dialog box
		infoLogLength>1 ? printf("%s", infoLog.data()) : printf("Failed to compile fragment shader.");

		return FALSE;
	}

	// Concept: Vertex Shaders
	// Vertex shaders primarily exist to allow a developer to express how to orient vertices in 3D space, through transformations like
	// Scaling, Translation or Rotation. Using the same basic layout and structure as a fragment shader, these take in vertex data and
	// output a fully transformed set of positions. Other inputs are also able to be used such as normals or texture coordinates, and can
	// also be transformed and output alongside the position data.
	
	// Vertex shader code
	const char* const vertexShaderSource = "\
	attribute highp vec4	myVertex;\
	uniform mediump mat4	transformationMatrix;\
	void main(void)\
	{\
	gl_Position = transformationMatrix * myVertex;\
	}";

	// Create a vertex shader object
	vertexShader = glCreateShader(GL_VERTEX_SHADER);

	// Load the source code into the shader
	glShaderSource(vertexShader, 1, (const char**)&vertexShaderSource, NULL);

	// Compile the shader
	glCompileShader(vertexShader);

	// Check the shader has compiled
	glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &isShaderCompiled);
	if (!isShaderCompiled)
	{
		// If an error happened, first retrieve the length of the log message
		int infoLogLength, charactersWritten;
		glGetShaderiv(vertexShader, GL_INFO_LOG_LENGTH, &infoLogLength);

		// Allocate enough space for the message and retrieve it
		std::vector<char> infoLog; infoLog.resize(infoLogLength);
		glGetShaderInfoLog(vertexShader, infoLogLength, &charactersWritten, infoLog.data());

		// Display the error in a dialog box
		infoLogLength>1 ? printf("%s", infoLog.data()) : printf("Failed to compile vertex shader.");

		return FALSE;
	}

	// Create the shader program
	shaderProgram = glCreateProgram();

	// Attach the fragment and vertex shaders to it
	glAttachShader(shaderProgram, fragmentShader);
	glAttachShader(shaderProgram, vertexShader);

	// Bind the vertex attribute "myVertex" to location VertexArray (0)
	glBindAttribLocation(shaderProgram, VertexArray, "myVertex");

	// Link the program
	glLinkProgram(shaderProgram);

	// Check if linking succeeded in the same way we checked for compilation success
	GLint isLinked;
	glGetProgramiv(shaderProgram, GL_LINK_STATUS, &isLinked);
	if (!isLinked)
	{
		// If an error happened, first retrieve the length of the log message
		int infoLogLength, charactersWritten;
		glGetProgramiv(shaderProgram, GL_INFO_LOG_LENGTH, &infoLogLength);

		// Allocate enough space for the message and retrieve it
		char* infoLog = new char[infoLogLength];
		glGetProgramInfoLog(shaderProgram, infoLogLength, &charactersWritten, infoLog);

		// Display the error in a dialog box
		infoLogLength>1 ? printf("%s", infoLog) : printf("Failed to link shader program.");

		delete[] infoLog;
		return FALSE;
	}

	// Use the Program
	// Calling glUseProgram tells OpenGL ES that the application intends to use this program for rendering. Now that it's installed into
	// the current state, any further glDraw* calls will use the shaders contained within it to process scene data. Only one program can
	// be active at once, so in a multi-program application this function would be called in the render loop. Since this application only
	// uses one program it can be installed in the current state and left there.
	glUseProgram(shaderProgram);
	if (![self testGLError:"glUseProgram"]){return FALSE;}
	return TRUE;
}

/*!*********************************************************************************************************************
\param[in] 		notification
\brief	Called when the application has finished launching.
***********************************************************************************************************************/
- (void) applicationDidFinishLaunching:(NSNotification *)notification
{
    // Create our window
    NSRect frame = NSMakeRect(0,0,Width, Height);
    m_window = [[NSWindow alloc] initWithContentRect:frame styleMask:NSMiniaturizableWindowMask | NSTitledWindowMask | NSClosableWindowMask
											 backing:NSBackingStoreBuffered defer:NO];
    
    if(!m_window)
    {
        NSLog(@"Failed to allocated the window.");
        [self terminateApp];
    }
    
    [m_window setTitle:@"OGLESHelloAPI"];
    
    // Create our view
    m_view = [[NSView alloc] initWithFrame:frame];
    
    // Now we have a view, add it to our window
    [m_window setContentView:m_view];
    [m_window makeKeyAndOrderFront:nil];

    // Add an observer so when our window is closed we terminate the app
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(terminateApp) name:NSWindowWillCloseNotification
											   object:m_window];
    
    EGLConfig config;

    // Create and Initialize an EGLDisplay
    if(![self createEGLDisplay:m_Display]){	[self terminateApp]; }

	// Choose an EGLConfig for the application, used when setting up the rendering surface and EGLContext
	if(![self chooseEGLConfig:config fromDisplay:m_Display]){	[self terminateApp];  }

	// Create an EGLSurface for rendering
	if(![self createEGLSurface:m_Surface fromDisplay:m_Display withConfig:config withView:m_view]){	[self terminateApp]; }

	// Setup the EGL Context from the other EGL constructs created so far, so that the application is ready to submit OpenGL ES commands
	if(![self setupEGLContext:m_Context fromDisplay:m_Display withConfig:config withSurface:m_Surface]){ [self terminateApp]; }

	// Initialize the vertex data in the application
	if(![self initializeBuffer:m_vertexBuffer])	{	[self terminateApp];  }

	// Initialize the fragment and vertex shaders used in the application
	if(![self initializeFragmentShader:m_fragShader andVertexShader:m_vertexBuffer withProgram:_program]){		[self terminateApp];	}

    // Setup a timer to redraw the view at a regular interval
    m_timer = [NSTimer scheduledTimerWithTimeInterval:(1.0 / Kfps) target:self selector:@selector(renderScene) userInfo:nil repeats:YES];
}

/*!*********************************************************************************************************************
\param[in]			eglDisplay                  The EGLDisplay used by the application
\param[in]			eglSurface					The EGLSurface created by the application
\return		Whether the function succeeds or not.
\brief	Renders the scene to the framebuffer. Usually called within a loop.
***********************************************************************************************************************/
- (BOOL) renderScene
{
	// Set the clear color
	// At the start of a frame, generally you clear the image to tell OpenGL ES that you're done with whatever was there before and want to
	// draw a new frame. In order to do that however, OpenGL ES needs to know what color to set in the image's place. glClearColor
	// sets this value as 4 floating point values between 0.0 and 1.0, as the Red, Green, Blue and Alpha channels. Each value represents
	// the intensity of the particular channel, with all 0.0 being transparent black, and all 1.0 being opaque white. Subsequent calls to
	// glClear with the color bit will clear the frame buffer to this value.
	// The functions glClearDepth and glClearStencil allow an application to do the same with depth and stencil values respectively.
	glClearColor(0.00, 0.70, 0.67, 1.0f);

	// Clears the color buffer.
	// glClear is used here with the Color Buffer to clear the color. It can also be used to clear the depth or stencil buffer using
	// GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT, respectively.
	glClear(GL_COLOR_BUFFER_BIT);

	// Get the location of the transformation matrix in the shader using its name
	int matrixLocation = glGetUniformLocation(_program, "transformationMatrix");

	// Matrix used to specify the orientation of the triangle on screen.
	const float transformationMatrix[] =
	{
		1.0f,0.0f,0.0f,0.0f,
		0.0f,1.0f,0.0f,0.0f,
		0.0f,0.0f,1.0f,0.0f,
		0.0f,0.0f,0.0f,1.0f
	};

	// Pass the transformationMatrix to the shader using its location
	glUniformMatrix4fv(matrixLocation, 1, GL_FALSE, transformationMatrix);
	if (![self testGLError:"glUniformMatrix4fv"]){	return FALSE;	}

	// Enable the user-defined vertex array
	glEnableVertexAttribArray(VertexArray);

	// Sets the vertex data to this attribute index, with the number of floats in each position
	glVertexAttribPointer(VertexArray, 3, GL_FLOAT, GL_FALSE, 0, 0);
	if (![self testGLError:"glVertexAttribPointer"]){	return FALSE;	}

	//	Draw the triangle
	// glDrawArrays is a draw call, and executes the shader program using the vertices and other state set by the user. Draw calls are the
	// functions which tell OpenGL ES when to actually draw something to the framebuffer given the current state.
	// glDrawArrays causes the vertices to be submitted sequentially from the position given by the "first" argument until it has processed
	// "count" vertices. Other draw calls exist, notably glDrawElements which also accepts index data to allow the user to specify that
	// some vertices are accessed multiple times, without copying the vertex multiple times.
	// Others include versions of the above that allow the user to draw the same object multiple times with slightly different data, and
	// a version of glDrawElements which allows a user to restrict the actual indices accessed.
	glDrawArrays(GL_TRIANGLES, 0, 3);
	if (![self testGLError:"glDrawArrays"]){	return FALSE;	}

	// Invalidate the contents of the specified buffers for the framebuffer to allow the implementation further optimization opportunities.
	// The following is taken from https://www.khronos.org/registry/OpenGL/extensions/EXT/EXT_discard_framebuffer.txt
	// Some OpenGL ES implementations cache framebuffer images in a small pool of fast memory.  Before rendering, these implementations must load the
	// existing contents of one or more of the logical buffers (color, depth, stencil, etc.) into this memory.  After rendering, some or all of these
	// buffers are likewise stored back to external memory so their contents can be used again in the future.  In many applications, some or all of the
	// logical buffers  are cleared at the start of rendering.  If so, the effort to load or store those buffers is wasted.

	// Even without this extension, if a frame of rendering begins with a full-screen Clear, an OpenGL ES implementation may optimize away the loading
	// of framebuffer contents prior to rendering the frame.  With this extension, an application can use DiscardFramebufferEXT to signal that framebuffer
	// contents will no longer be needed.  In this case an OpenGL ES implementation may also optimize away the storing back of framebuffer contents after rendering the frame.
	if(isGlExtensionSupported("GL_EXT_discard_framebuffer"))
	{
		GLenum invalidateAttachments[2];
		invalidateAttachments[0] = GL_DEPTH_EXT;
		invalidateAttachments[1] = GL_STENCIL_EXT;
		
		glDiscardFramebufferEXT(GL_FRAMEBUFFER, 2, &invalidateAttachments[0]);
		if (![self testGLError:"glDiscardFramebufferEXT"]){	return false;	}
	}

	// Present the display data to the screen.
	// When rendering to a Window surface, OpenGL ES is double buffered. This means that OpenGL ES renders directly to one frame buffer,
	// known as the back buffer, whilst the display reads from another - the front buffer. eglSwapBuffers signals to the windowing system
	// that OpenGL ES 2.0 has finished rendering a scene, and that the display should now draw to the screen from the new data. At the same
	// time, the front buffer is made available for OpenGL ES 2.0 to start rendering to. In effect, this call swaps the front and back
	// buffers.
	if (!eglSwapBuffers(m_Display, m_Surface) )	
    {	
        [self testGLError:"eglSwapBuffers"];
        return FALSE;
	}
	return TRUE;
}

/*!*********************************************************************************************************************
\brief	Releases the resources
***********************************************************************************************************************/
- (void) deInitializeGLState
{
	// Frees the OpenGL handles for the program and the 2 shaders
	glDeleteShader(m_fragShader);
	glDeleteShader(m_vertexShader);
	glDeleteProgram(_program);

	// Delete the VBO as it is no longer needed
	glDeleteBuffers(1, &m_vertexBuffer);
}

/*!*********************************************************************************************************************
\param[in]			eglDisplay                   The EGLDisplay used by the application
\brief	Releases all resources allocated by EGL
***********************************************************************************************************************/
- (void) releaseEGLState:(EGLDisplay)eglDisplay
{
	// To release the resources in the context, first the context has to be released from its binding with the current thread.
	eglMakeCurrent(eglDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);

	// Terminate the display, and any resources associated with it (including the EGLContext)
	eglTerminate(eglDisplay);
}

/*!*********************************************************************************************************************
\brief   Called when the app is about to terminate.
***********************************************************************************************************************/
- (void) applicationWillTerminate:(NSNotification *)notification
{
    // Release our timer
    [m_timer invalidate];

	[self deInitializeGLState];
	[self releaseEGLState:m_Display];

    // Release our view and window
    [m_view release];
    m_view = nil;
    
    [m_window release];
    m_window = nil;
}

/*!*********************************************************************************************************************
\brief   Attempts to immediately terminate the application.
***********************************************************************************************************************/
- (void) terminateApp
{
    [NSApp terminate:nil];
}

@end

/*!*********************************************************************************************************************
\param[in]			argc           Number of arguments passed to the application, ignored.
\param[in]			argv           Command line strings passed to the application, ignored.
\return		Result code to send to the Operating System
\brief	Main function of the program, executes other functions.
***********************************************************************************************************************/
int main(int argc, char **argv){	return NSApplicationMain(argc, (const char **)argv);  }

