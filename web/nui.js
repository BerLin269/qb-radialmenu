window.addEventListener('message', function(event) {
    const radialMenu = document.querySelector('.radial-menu');
    const menuCenter = document.querySelector('.menu-center');
    let shape = 'hex';
    let animation = 'GG';
    let menuItems = [];
    let subMenuHistory = [];

    function createMenuItem(title, icon, type) {
        const menuItem = document.createElement('div');
        menuItem.className = 'menu-item';
        
        let iconHtml = '';
        if (icon.startsWith('http') || icon.startsWith('https')) {
            iconHtml = `<img src="${icon}" alt="${title} icon" class="icon-image" style="width: 25px; height: 25px;">`;
        } else {
            if (!icon.includes('fa-')) {
                icon = 'fa-light fa-' + icon;
            }
            iconHtml = `<i class="${icon}"></i>`;
        }
        
        menuItem.innerHTML = `
            <div class="menu-icon">
                ${iconHtml}
            </div>
            <div class="menu-label">${title}</div>
        `;
        menuItem.dataset.label = title;
        menuItem.dataset.type = type;
        menuItem.addEventListener('click', function() {
            const audio = new Audio('audio.wav');
            audio.volume = 0.1;
            audio.play();
        });
        
        return menuItem;
    }

    function positionMenuItems(menuItems) {
        const radius = 105;
        const positions = [];
        
        positions.push({ x: 0, y: 0 });
        
        for (let i = 0; i < 6; i++) {
            const angle = (Math.PI / 3) * i;
            positions.push({
                x: radius * Math.cos(angle),
                y: radius * Math.sin(angle)
            });
        }
        
        for (let i = 0; i < 6; i++) {
            const angle = (Math.PI / 3) * i;
            positions.push({
                x: 2 * radius * Math.cos(angle),
                y: 2 * radius * Math.sin(angle)
            });
            const nextAngle = (Math.PI / 3) * ((i + 1) % 6);
            positions.push({
                x: radius * (Math.cos(angle) + Math.cos(nextAngle)),
                y: radius * (Math.sin(angle) + Math.sin(nextAngle))
            });
        }

        menuItems.forEach((item, index) => {
            if (index < positions.length) {
                item.style.transform = `translate(${positions[index].x}px, ${positions[index].y}px)`;
            }
        });
    }

    function applyAnimation(elements) {
        let animationConfig = {
            targets: elements,
            scale: [0, 1],
            opacity: [0, 1],
            duration: 200,
            easing: 'easeOutQuint',
            delay: anime.stagger(20),
            complete: function(anim) {
                document.body.style.transform = 'none'; // Force GPU render
            }
        };
        
        anime(animationConfig);
    }

    function updateMenu(items) {
        const existingItems = radialMenu.querySelectorAll('.menu-item');
        existingItems.forEach(item => item.remove());

        const closeButton = createMenuItem('Close', 'fa-light fa-xmark fa-fade', 'client');
        closeButton.classList.add('close-button');
        radialMenu.appendChild(closeButton);
        closeButton.onclick = function() {
            fetch(`https://${GetParentResourceName()}/closeRadial`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                body: JSON.stringify({})
            }).then(resp => resp.json());
        };

        if (subMenuHistory.length > 0) {
            const backButton = createMenuItem('Back', 'fa-light fa-arrow-left fa-fade', 'client');
            backButton.onclick = function() {
                if (subMenuHistory.length > 0) {
                    const previousMenu = subMenuHistory.pop();
                    updateMenu(previousMenu);
                }
            };
            radialMenu.appendChild(backButton);
        }

        items.forEach(item => {
            const menuItem = createMenuItem(item.title, item.icon, item.type);
            menuItem.onclick = function() {
                if (item.items) {
                    subMenuHistory.push(items);
                    updateMenu(item.items);
                } else if (item.event) {
                    fetch(`https://${GetParentResourceName()}/selectItem`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json; charset=UTF-8',
                        },
                        body: JSON.stringify({
                            event: item.event,
                            type: item.type || 'client',
                            shouldClose: item.shouldClose
                        })
                    }).then(resp => resp.json());
                    
                    if (item.shouldClose) {
                        fetch(`https://${GetParentResourceName()}/closeRadial`, {
                            method: 'POST',
                            headers: {
                                'Content-Type': 'application/json; charset=UTF-8',
                            },
                            body: JSON.stringify({})
                        }).then(resp => resp.json());
                    }
                }
            };
            radialMenu.appendChild(menuItem);
        });

        positionMenuItems(radialMenu.querySelectorAll('.menu-item'));

        applyAnimation(radialMenu.querySelectorAll('.menu-item'));
    }
    
    if (event.data.action === 'opening') {
        menuItems = event.data.items;
        subMenuHistory = [];
        radialMenu.style.display = 'block';
        radialMenu.style.animation = 'zoomIn 0.2s cubic-bezier(0.16, 1, 0.3, 1)';
        requestAnimationFrame(() => {
            updateMenu(menuItems);
        });
    } else if (event.data.action === 'close') {
        radialMenu.style.animation = 'zoomOut 0.2s cubic-bezier(0.16, 1, 0.3, 1)';
        setTimeout(() => {
            radialMenu.style.display = 'none';
            radialMenu.style.animation = '';
            radialMenu.querySelectorAll('.menu-item').forEach(item => item.remove());
            menuCenter.textContent = '';
            subMenuHistory = [];
        }, 200);
    }
});