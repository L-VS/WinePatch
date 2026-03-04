// Smooth Scroll
const smoothScroll = (target) => {
    document.querySelector(target).scrollIntoView({
        behavior: 'smooth'
    });
};

// Interactive Elements
document.querySelectorAll('.interactive').forEach(item => {
    item.addEventListener('click', event => {
        // Your interactive code here
    });
});

// Dynamic Content Display
const dynamicContent = () => {
    const content = document.getElementById('dynamicContent');
    content.innerHTML = '<p>New Dynamic Content Loaded!</p>';
};

// Call dynamic content once
dynamicContent();