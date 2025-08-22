/*
 Copyright (C) 2025 NoQCNoLife Contributors
 
 This file is part of 'No QC, No Life'.
 
 'No QC, No Life' is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 1, or (at your option)
 any later version.
 
 'No QC, No Life' is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

import SwiftUI

// Temporary stub to fix build issues
// This file has been temporarily simplified to resolve compilation errors
// The full SwiftUI interface will be restored once the menu bar icon issue is fixed

struct MainContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack {
            Text("NoQCNoLife")
                .font(.headline)
                .padding()
            
            if appState.isConnected {
                Text("Connected")
                    .foregroundColor(.green)
            } else {
                Text("Not Connected")
                    .foregroundColor(.red)
            }
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .padding()
        }
        .frame(width: 280, height: 200)
    }
}